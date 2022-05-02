# Contest.net Display Unit - Worker Process

The Contest.net Display Unit is a kiosk for displaying content such as pre-event sales advertisments, promotional videos, and during the event
the live leader board display to show overall standings and new entry placement details.

These units run in remote locations that are time consuming to reach, so emphasis is put on the reliability and remote control of the units.


This project is broken into three repositories
* [Configuration](https://github.com/josh-hetland/Contest.net-Unit-Configuration)
* [Launcher](https://github.com/josh-hetland/Contest.net-Unit-Launcher)
* [Worker](https://github.com/josh-hetland/Contest.net-Unit-Worker) _(this one)_


The Worker is the main process that runs on the client to coordinate activities. It is bundled as a single file to simplify the delivery and validation
of it through the automatic update sequence and to easily fall back to the previous version if it fails to start.


## Launch Sequence

This will be an outline of what the contestnet client does in the order it does it for troubleshooting later on so i don't have to dig into the code.

### Launcher: 
	This is the bootstrapper which starts the worker and handles the application of updates to the worker.
	The worker handles pulling down updates which launcher will check for and put into place.
	
	Launcher sets up some of the environment that worker needs to run in such as the desktop manager and what not
	after that it beens a loop that continously runs the following sequence
	
	BEGIN LOOP
	Looks for ./worker.new (an update)
		Moves ./worker to ./worker.restore
		Moves ./worker.new to ./worker
	Launches ./worker with no agruments
		On bad exit code (IE the interpreter throws an error IE bad source file)
			Moves ./worker to ./worker.bad (may be needed for reference)
			Moves ./worker.restore ./worker
		On restart exit code
			executes a shutdown -r command
		On shutdown exit code
			executes a shutdown -h command
	END LOOP

	This allows for safe fallback on retrieval of a bad update and for the worker to update itself by just exiting cleanly since the update 
	will be found on the next loop.

### Worker:
	This runs in two (well three if you count the synchronizer, well four if you count the process monitor thread) threads. 
	one dedicated to processing a task (IE displaying something to the screen), and the other dedicated to checking in with the 
	server and getting new tasks to be processed as well as updating itself and issuing system commands like shutdown.
	
	Maintenance sequence:
		Task change operatations, and metadata collection take place on a background thread
		to not block the display thread. When the maintenance tasks are complete if the task
		has changed the display thread is notified and restarts itself
	Display sequence:

	Process Monitor sequence:
		Certain processes do not like to exit well and leave behind bad state. the process monitor thread watchs
		for exits and checks the type to determine if there are any extra cleanup operations carry out.

		in earlier versions the midori browser was used and it needed to be cleaned up but that has been changed to chromium since

		the omxplayer leaves some TVs in a bad state, and the display needs to be cycled on & off to clean up

		