# Contest.net Display Unit - Worker Process

The Contest.net Display Unit is a kiosk for displaying content such as pre-event sales advertisments, promotional videos, and during the event
the live leader board display to show overall standings and new entry placement details.


This project is broken into three repositories
* Configuration
* Launcher
* Worker


## Launch Sequence

This will be an outline of what the contestnet client does in the order it does it for troubleshooting later on so i don't have to dig into the code.

Launcher: 
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

Worker:
	This runs in two (well three if you count the synchronizer, well four if you count the process monitor thread) threads. 
	one dedicated to processing a task (IE displaying something to the screen), and the other dedicated to checking in with the 
	server and getting new tasks to be processed as well as updating itself and issuing system commands like shutdown.
	
	Maintenance sequence:
		