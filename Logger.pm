package Logger;

use 5.8.0;
use strict;
use warnings;

use IO::File;
use File::Copy;
use File::Basename;
use POSIX;
require Exporter;

our @ISA = ('Exporter');
our @EXPORT = ('LOG_NONE','LOG_INFO','LOG_WARN','LOG_ERROR','LOG_FATAL','LOG_DEBUG');
our $VERSION = '1.3.0';

###################################################
#             Constant Declarations               #
###################################################
use constant {
  LOG_NONE  => 0,
  LOG_INFO  => 1,
  LOG_WARN  => 2,
  LOG_ERROR => 4,
  LOG_FATAL => 8,
  LOG_DEBUG => 16
};
# This allows you to set which messages should come through or stack as many as you like when
# using conditional write methods 
# All Messages: 31, No Debug: 15 


###################################################
#          Constructor / Destructor               #
###################################################

### [new]: Constructs a new Logger object
### Parameters:
### Return: Object
### Notes: This still needs to be changed to allow for options on construction
sub new {
  my $class = shift @_;
  #i could allow for optional arguments here
  # one being the log file
  #what order do I want to take things?
  #path (it would be assumed that you want file logging enabled right?)
  #level
  #enabled state for console and file logging?
  #archive option
  #max size option
  my $self = {
    # Public backers
    iLevel            => 13, #Logging level (Default All but debug and warn)
    bFileLogging      => 0, #Indicates if file logging should occur (Default NO)
    bConsoleLogging   => 0, #Indicates if console logging should occur (Default YES)
    bConsoleTimestamp => 0, #Indicates if console output should include a timestamp (Default NO)
    bArchiveLogs      => 1, #Indicates if log files that have exceeded the size should be archived
    sFilePath         => POSIX::strftime('%Y%d%m_%H%M%S.log',localtime(time())), #Path to log file (Default to timestamp of construction)
    iMaxBytes         => 5242880, #default max size of 5242880 (5MB @ 1:1,048,576)
    bNewLine          => 1, #Indicates if a new line was included in the last write
    sStampFormat      => "[%m/%d/%Y %H:%M:%S] ", #Timestamp format used when logging
    bTrapWarnings     => 0
  };
  bless $self, $class;
  return $self;
}
#new


### [DESTROY]: Called on the cleanup phase
###
### Return: Boolean (Void context)
sub DESTROY {
  my $self = shift @_;
  $self->Cleanup();
}
#DESTROY



###################################################
#                Properties                       #
###################################################

### [LoggingLevel]: Sets or Gets the output options for conditional logging.
### Parameters:
###   $iValue: (Integer) Concatenation of output levels to be included when conditionally logging 
### Return: Integer
###   The currently set logging options
### Notes:  This isn't done, deciding if it needs validation or not
sub LoggingLevel { #( $iValue )
  my $self = shift @_;
  if(@_){ #Setter mode
    my $Value = shift @_;
    $self->{iLevel} = $Value; #There is no validation on this, do i want there to be?
  }
  return $self->{iLevel}; #Getter mode, always returns the level
}
#LoggingLevel


### [FileLogging]: Sets or Gets the option to log to a file.
### Parameters:
###   $bEnabled: (Boolean) Any value that can be interpreted as a true or false 
### Return: Boolean
###   Indicates the current state of the FileLogging option
sub FileLogging { #( $bEnabled )
  my $self = shift @_;
  if(@_) { #Setter Mode (If an argument exists, update the internal value with it)
    $self->{bFileLogging} = ($_[0])? 1 : 0;
  }#@_
  return $self->{bFileLogging}; #Getter Mode
}
#FileLogging


### [ConsoleLogging]: Sets or Gets the option to log to the console.
### Parameters:
###   $bEnabled: (Boolean) Any value that can be interpreted as a true or false 
### Return: Boolean
###   Indicates the current state of the ConsoleLogging option
sub ConsoleLogging { #( $bEnabled )
  my $self = shift @_;
  if(@_) { #Setter Mode (If an argument exists, update the internal value with it)
    $self->{bConsoleLogging} = ($_[0])? 1 : 0;
  }#@_
  return $self->{bConsoleLogging}; #Getter Mode
}
#ConsoleLogging


### [ConsoleTimestamp]:
###   Sets or Gets the option to prefix console output with a timestamp
###   (which can make the lines pretty long)
### Parameters:
###   $bEnabled: (Boolean) Any value that can be interpreted as a true or false
### Return: Boolean
###   Indicates the current state of the ConsoleTimestamp option
sub ConsoleTimestamp { #( $bEnabled )
  my $self = shift @_;
  if(@_){ #Setter Mode (If an argument exists, update the internal value with it)
    $self->{bConsoleTimestamp} = ($_[0])? 1 : 0;
  }#@_
  return $self->{bConsoleTimestamp}; #Getter Mode
}
#ConsoleTimestamp


### [FilePath]: Sets or Gets the path to the log file.
###   Environment variables will be expanded automatically. In the event that an included environment variable
###   is not actually found on the system the variable marks will be stripped from the name and the name will be inserted
###   in place of the expansion.
### Parameters:
###   $sPath: (String) Path to the log file to be written
### Return: String
###   Path to the currently set log file path
### Notes:
###   On object construction a default value is set to FilePath equivelant to "timestamp.log"
###   in the current working directory.
sub FilePath { #( $sPath )
  my $self = shift @_;
  if(@_) { #Setter Mode
    my $Windows = ($^O eq "MSWin32")? 1 : 0;
    my $Path = shift @_;
    
    #Handle OS specific environment variables
    if($Windows){ #Windows Environment Variable Handling
      while($Path =~ m/(%(.+?)%)/){
        my $Match = $1;
        my $Replace = $2; #Default the replaced value to the variable name
        if($ENV{$2}){ #Make sure the environment variable exists before using it
          $Replace = $ENV{$2}; #update
        }#$ENV{$2}
        $Path =~ s/$Match/$Replace/;
      }#while
      
      #Check if root directory is not valid (what am i going to do if it isn't though?)
      my @PathParts = split(/\\|\//,$Path);
      if((@PathParts > 1) && ! -d $PathParts[0]){ #Warn if there is a root specified and it does not exist
        warn "Logger: Invalid root directory in path! I hope you know what you're doing...\n";
      }# root directory doesn't exist
      
    }else{ #Linux Environment Variable Handling (this is currently untested)
      while($Path =~ m/(\$(.+?))\//){
        my $Match = quotemeta( $1 );
        my $Replace = $2; #Default the replaced value to the variable name
        if($ENV{$2}){ #Make sure the environment variable exists before using it
          $Replace = $ENV{$2}; #update
        }#$ENV{$2}
        $Path =~ s/$Match/$Replace/;
      }#while
    }#Os Type
    
    
    #Relative path marker handling
    #  i don't know how i'm going to do this at the moment
    
    $self->{sFilePath} = $Path;
    $self->Cleanup(); #Call the cleanup method to check if it needs to be cycled.
  }#Setter Mode
  return $self->{sFilePath}; #Getter Mode (Always)
}
#FilePath


### [NewLine]: Gets a value indicating if the last operation performed included a line termination.
### Return: Boolean
###   Indicates the state of the last operation performed.
sub NewLine { #( )
  my $self = shift @_;
  return $self->{bNewLine}; #Getter Mode
}
#NewLine


### [MaxSize]: Sets or Gets maximum desired log file size used when determining if a cleanup is needed
### Parameters:
###   $vSize: (Variant) numeric or string representation of the desired maximum size
###     numeric values are treated as bytes where string values are interpreted based on
###     the letter prefixes (For instance: b, Kb, Mb, Gb, Tb, Pb) - those last few aren't really advised though
### Return: Integer
###   Currently set maximum size in bytes
sub MaxSize { #( $vSize )
  my $self = shift @_;
  if(@_){ #Setter mode
    my $Value = shift @_;
    my $Suffix; #Will hold a suffix if one is found
    #If the value does not work in this expression it will be regected.
    #but honestly... why would you want to set a max size for a log file to "Hello, World!"?
    if($Value =~ m/([0-9\.]+)?(b|k|m|g|t|p)?/i){
      $Value = $1;
      $Suffix = lc($2 || '');
      
      if($Suffix && ($Suffix ne 'b')){ #Conversion needed
        if($Suffix eq 'k'){ #Kilobyte Conversion
          $Value *= 1024;
        }
        if($Suffix eq 'm'){ #Megabyte Conversion
          $Value *= 1048576;
        }
        if($Suffix eq 'g'){ #Gigabyte Conversion (This really shouldn't be necessary)
          $Value *= 1073741824;
        }
        if($Suffix eq 't'){ #Terabyte Conversion (I'm not sure why i added this)
          $Value *= 1099511627776;
        }
        if($Suffix eq 'p'){ #Petabyte Conversion (Now i'm just being silly)
          $Value *= 1125899906842624; #(1.12589991 * 10**15)
        }
      }#$Suffix
      
      $self->{iMaxBytes} = $Value;
    }
  }#Setter Mode
  return ($self->{iMaxBytes}); # / 1024); #Getter mode (b)
}
#MaxSize


### [ArchiveLogs]: Sets or Gets the option to archive logs that have exceeded [MaxSize] during a cleanup process
### Parameters:
###   $bEnabled: (Boolean) Any value that can be interpreted as a true or false 
### Return: Boolean
###   Indicates the current state of the ArchiveLogs option
sub ArchiveLogs { #( $bEnabled )
  my $self = shift @_;
  if(@_) { #Setter Mode (If an argument exists, update the internal value with it)
    $self->{bArchiveLogs} = ($_[0])? 1 : 0;
  }#@_
  return $self->{bArchiveLogs}; #Getter Mode
}
#ArchiveLogs


### [TrapWarnings]:
###   Hooks into the __WARN__ Signal and forwards anything that comes in to the logging streams
###   as a conditional warn message.
### Parameters:
###   $bEnabled: (Boolean) Any value that can be interpreted as a true or false 
### Notes:
###   This is pretty experimental at this point, I have no idea if this will cause problems
###   with anything. It may be wiser for mission critical code to handle the trap yourself
sub TrapWarnings { #( $bEnabled )
  my $self = shift @_;
  if( defined($_[0]) ){
    my $bEnabled = shift @_;
    
    if( $bEnabled ){
      $SIG{__WARN__} = sub {
        $self->Warn($_[0]);
        warn($_[0]);
      };
      $self->{bTrapWarnings} = 1;
      
      
    }else{
      $self->{bTrapWarnings} = 0;
      $SIG{__WARN__}         = undef;
    }
    
  }
  
  return $self->{bTrapWarnings};
}
### TrapWarnings




###################################################
#               Public Methods                    #
###################################################

#***************************************#
#      Conditional Write Methods        #
#***************************************#

### [Debug]:
###   Writes a terminating line to the enabled logging streams prefixed with "Debug: " if the debugging level is set.
### Parameters:
###   $sText: (String) Text to be written
### Return: Boolean
###   Indicates if the operation was successful or not
sub Debug { #( $sText )
  my $self = shift @_;
  my $Text = shift @_ || undef;
  my $Return = 0;
  if($Text && ($self->{iLevel} & LOG_DEBUG)){
    if(! $self->{bNewLine}){ #Pending line exists
      $self->WriteLine(''); #Close it
    }#Pending line exists
    $Return = $self->WriteLine('Debug: ' . $Text);
  }#Should log
  return $Return;
}
#Debug


### [Info]:
###   Writes a terminating line to the enabled logging streams prefixed with "Info: " if the info level is set.
### Parameters:
###   $sText: (String) Text to be written
### Return: Boolean
###   Indicates if the operation was successful or not
sub Info { #( $sText )
  my $self = shift @_;
  my $Text = shift @_ || '';
  my $Return = 0;
  if($Text && ($self->{iLevel} & LOG_INFO)){
    if(! $self->{bNewLine}){ #Pending line exists
      $self->WriteLine(''); #Close it
    }#Pending line exists
    $Return = $self->WriteLine('Info   : ' . $Text);
  }#Should log
  return $Return;
}
#Info


### [Warn]:
###   Writes a terminating line to the enabled logging streams prefixed with "Warning: " if the warn level is set.
### Parameters:
###   $sText: (String) Text to be written
### Return: Boolean
###   Indicates if the operation was successful or not
sub Warn { #( $sText )
  my $self = shift @_;
  my $Text = shift @_ || '';
  my $Return = 0;
  if($Text && ($self->{iLevel} & LOG_WARN)){
    if(! $self->{bNewLine}){ #Pending line exists
      $self->WriteLine(''); #Close it
    }#Pending line exists
    $Return = $self->WriteLine('Warning: ' . $Text);
  }#Should log
  return $Return;
}
#Warn


### [Error]:
###   Writes a terminating line to the enabled logging streams prefixed with "Error: " if the debugging level is set.
### Parameters:
###   $sText: (String) Text to be written
### Return: Boolean
###   Indicates if the operation was successful or not
sub Error { #( $sText )
  my $self = shift @_;
  my $Text = shift @_ || '';
  my $Return = 0;
  if($Text && ($self->{iLevel} & LOG_ERROR)){
    if(! $self->{bNewLine}){ #Pending line exists
      $self->WriteLine(''); #Close it
    }#Pending line exists
    $Return = $self->WriteLine('Error  : ' . $Text);
  }#Should log
  return $Return;
}
#Error


### [Fatal]:
###   Writes a terminating line to the enabled logging streams prefixed with "Fatal Error: " if the fatal level is set.
### Parameters:
###   $sText: (String) Text to be written
### Return: Boolean
###   Indicates if the operation was successful or not
sub Fatal { #( $sText )
  my $self = shift @_;
  my $Text = shift @_ || '';
  my $Return = 0;
  if($Text && ($self->{iLevel} & LOG_FATAL)){
    if(! $self->{bNewLine}){ #Pending line exists
      $self->WriteLine(''); #Close it
    }#Pending line exists
    $Return = $self->WriteLine('Fatal  : ' . $Text);
  }#Should log
  return $Return;
}
#Fatal



#***************************************#
#        Direct Write Methods           #
#***************************************#

### [Write]:
###   Writes a non-terminating line to the enabled logging streams. If an unterminated line exists
###   it will be appended to, if not a new line will be created and the line prefix will be included.
### Parameters:
###   $sText: (String) Text to be written
### Return: Boolean
###   Indicates if the operation was successful or not
sub Write { #( $sText )
  my $self = shift @_;
  my $Text = shift @_ || "";
  chomp($Text);
  my $Return = 1; #Default to good exit
  if($self->{bFileLogging}){
    if(! $self->__WriteFile(1,$Text)){
      $Return = 0; #Bad exit
    }
  }#File logging enabled
  
  if($self->{bConsoleLogging}){
    if(! $self->__WriteConsole(1,$Text)){
      $Return = 0; #Bad exit
    }
  }#Console logging enabled
  
  $self->{bNewLine} = 0; #mark that a line is still open
  return $Return;
}
#Write


### [WriteLine]:
###   Writes a terminating line to the enabled logging streams. If an unterminated line exists
###   it will be appended to, if not a new line will be created and the line prefix will be included.
### Parameters:
###   $sText: (String) Text to be written
### Return: Boolean
###   Indicates if the operation was successful or not
sub WriteLine { #( $sText )
  my $self = shift @_;
  my $Text = shift @_ || "";
  chomp($Text);
  my $Return = 1; #Default to a good exit
  
  if($self->{bFileLogging}){
    if(! $self->__WriteFile(2,$Text)){
      $Return = 0; #Bad exit
    }
  }#File logging enabled
  
  if($self->{bConsoleLogging}){
    if(! $self->__WriteConsole(2,$Text)){
      $Return = 0;#Bad exit
    }
  }#Console logging enabled
  
  if($Return != 0){ #If the write operations were successful
    $self->{bNewLine} = 1; #mark that a newline character was written on this transaction
  }
  return $Return;
}
#WriteLine


### [WriteBlankLines]:
###   Writes a series of [$iLineCount] unprefixed blank lines to the enabled logging streams.
###   If an unterminated line exists it will be terminated automatically before the blank lines are written.
### Parameters:
###   $iLineCount: (Integer) Text to be written
### Return: Boolean
###   Indicates if the operation was successful or not
sub WriteBlankLines { #( $iLineCount )
  my $self = shift @_;
  my $Count = shift @_ || 0;
  my $Return = 1; #Default to a good exit
  
  #If there is an open line it needs to be closed without counting against the desired count
  if(! $self->{bNewLine}){
    $Count++;
  }#Pending line exists
  
  for(my $i = 0; $i < $Count; $i++){
    if($self->{bFileLogging}){
      if(! $self->__WriteFile(3)){
        $Return = 0; #Bad exit
      }
    }#File logging enabled
  
    if($self->{bConsoleLogging}){
      if(! $self->__WriteConsole(3)){
        $Return = 0; #Bad exit
      }
    }#Console logging enabled
    
  }#next $i
  
  if($Return != 0){ #If the write operations were successful
    $self->{bNewLine} = 1; #mark that a newline character was written on this transaction
  }
  return $Return;
}
#WriteBlankLines



#***************************************#
#          File Maintenance             #
#***************************************#

### [Cleanup]:
###   Checks the log file specified in [FilePath] to see if it is above the maximum size threshold set
###   by [MaxSize] and cleans it if needed.
###   If [ArchiveLogs] or the optional parameter is true the file will be archived as "filename-timestamp.ext" first.
### Parameters:
###   $bBackup: (Boolean) Optional override parameter indicating if a file marked for cleaning should
###     be archived first. If omitted the value in [ArchiveLogs] is used.
### Return: Boolean
###   Indicates if a cleanup took place (IE: was needed)
sub Cleanup { #( $bBackup )
  my $self = shift @_;
  my $Return = 0;
  my $SaveOldLog = $self->{bArchiveLogs}; #Default or object level set value for $SaveOldLog
  if(@_){ #Optional condition specified
    $SaveOldLog = ($_[0])? 1 : 0; #Set $SaveOldLog to the forced equivelant of the argument test
  }#Optional overwrite value
  
  if(-e $self->{sFilePath} && (-s $self->{sFilePath} > $self->{iMaxBytes})){ #Check if the file exceeds the max size
    if($self->{bArchiveLogs}){
      my ($File, $Directory, $Extension) = File::Basename::fileparse($self->{sFilePath},qr/\.[^.]*/); #Break the file up into parts
      $File .= POSIX::strftime('-%Y%d%m_%H%M%S',localtime(time())); #Added a timestamp to the file name
      File::Copy::move($self->{sFilePath},$Directory . $File . $Extension); #Move the file to its new name
    }#bArchiveLogs
    
    #Clear the file by opening it in overwrite mode and then close it again.
    my $fHandle = new IO::File($self->{sFilePath},'>');
    $fHandle->close();
    $Return = 1; #return that it was cleaned
  }#File exceeds limit
  
  return $Return;
}
#Cleanup



###################################################
#               Private Methods                   #
###################################################

### [__WriteFile]: (Internal)
###   Private method that maintains and controls all access to the log file requested by upstream methods.
### Parameters:
###   $iLineType: (Integer) Type of line being written
###     [1]: Non-terminating line
###     [2]: Terminating line
###     [3]: Blank terminating line
###   $sText: (String) Text to be written
### Return: Boolean
###   Indicates if the operation was successful or not
### Notes:
###   Thread saftey unfortunately can not be forced, it needs to be implemented at a higher level
###   will need to include an example in the documentation for this.
sub __WriteFile { #( $iLineType, $sText )
  my $self = shift @_;
  my $Type = shift @_; #this will be the type code to determine the style of writting
  my $Text = shift @_ || ""; #the stuff to be written (on Blanklines this will be undef)
  my $Return = 0; #Return value
  
  lock($self);
  
  #Open the file handle for appending
  my $fHandle = new IO::File($self->{sFilePath},'>>');
  if($fHandle){
    $fHandle->autoflush();
    my $Line; #What will eventually get written to the file
    
    if($self->{bNewLine} && ($Type != 3)){ #Newline and NOT Blankline
      $Line .= POSIX::strftime($self->{sStampFormat},localtime(time()));
    }#Newline and NOT Blankline
    
    $Line .= $Text; #on $Type==3 this will be undef
    
    if($Type > 1){ 
      $Line .= "\n"; #add the newline character to the line
    }
    print($fHandle $Line);
    $fHandle->close();
    $Return = 1;
  }#fHandle opened
  
  return $Return;
}
#__WriteFile


### [__WriteConsole]: (Internal)
###   Private method that maintains and controls all access to the standard output stream requested by upstream methods.
### Parameters:
###   $iLineType: (Integer) Type of line being written
###     [1]: Non-terminating line
###     [2]: Terminating line
###     [3]: Blank terminating line
###   $sText: (String) Text to be written
### Return: Boolean
###   Indicates if the operation was successful or not
sub __WriteConsole { #( $iLineType, $sText )
  my $self = shift @_;
  my $Type = shift @_; #this will be the type code to determine the style of writting
  #Possible Type Values:
  #  Write = 1
  #  WriteLine = 2
  #  Blank Lines = 3
  my $Text = shift @_ || ""; #the stuff to be written (on Blanklines this will be undef)
  my $Return = 0; #Return value

  my $Line; #What will eventually get written to the file

  if($self->{bConsoleTimestamp} && $self->{bNewLine} && ($Type != 3)){ #Newline and NOT Blankline
    $Line .= POSIX::strftime($self->{sStampFormat},localtime(time()));
  }#Newline and NOT Blankline

  $Line .= $Text; #on $Type==3 this will be undef

  if($Type > 1){ 
    $Line .= "\n"; #add the newline character to the line 
  }
  print(STDOUT $Line);
  $Return = 1;

  return $Return;
}
#__WriteConsole

1;
__END__


=pod

=head1 NAME

Logger

=head1 VERSION

1.1.1

=head1 SYNOPSIS

Logger - Provides a common object to handle logging to console or screen

    use 5.10.0;
    use Logger;
    
    my $Log = new Logger();
    $Log->FilePath('Logfile.log'); #Create file in cwd named Logfile.log
    $Log->FileLogging(1); #Enable file logging
    $Log->ConsoleLogging(1); #Enable console logging
    
    ## Conditional logging
    ##   These lines will only be output if the individual level is enabled
    $Log->Info('Something normal happened.');
    $Log->Warn('Something bad happend.');
    $Log->Error('Something went wrong here.');
    $Log->Fatal('Ok i think we\'re done here.');
    $Log->Debug('Here is some specific details.');
    
    ## Unconditional logging
    ##   These always happen
    $Log->Write('lets start something here...');
    $Log->Writeline(' Ok we\'re done!');



=head1 DESCRIPTION

Instantiates a common object used for controlling all logging operations within a program.
I<(this needs to be longer)>




=head2 Properties:

=head4 LoggingLevel I<(Default: C<15> IE: All levels but Debugging)>

Output for conditional methods are controlled by adjusting the C<LoggingLevel> property of C<$Log>. using the exported constants C<LOG_NONE>,
C<LOG_INFO>, C<LOG_WARN>, C<LOG_ERROR>, & C<LOG_DEBUG>. (By default all but C<LOG_DEBUG> are set.)

You can add or remove options from C<LoggingLevel> and even replace the options outright using bitwise operations on the constants
and the value of C<LoggingLevel>.

    #Enable Info, and Warn levels
    $Log->LoggingLevel( LOG_INFO | LOG_WARN );
    
    #Time passes....
    
    #Add Debug output
    $Log->LoggingLevel( $Log->LoggingLevel | LOG_DEBUG ); #Added it
    
    #Turns out you didn't want debugging enabled after all
    $Log->LoggingLevel( $Log->LoggingLevel ^ LOG_DEBUG ); #Remove it
    
    #Wait, did i remove that or not? here let me check..
    if( $Log->LoggingLevel & LOG_DEBUG ){
      #Yep, we're good to go, Debug is turned off
    }



=head4 FileLogging I<(Default: C<false>)>

The C<FileLogging> property of C<$Log> controls whether or not logging to file will occur. If enabled all logging events that are not filtered
will be output to the log file specified by C<FilePath> which if unaltered creates a file named "I<timestamp>.log" in the current working directory.

The file logging option can be altered by passing any parameter that will equate to C<true> or C<false> in a standard expression.

    #These will all enable the option
    $Log->FileLogging( "i'm not empty" ); #Or any other string that isn't empty and isn't a lone '0'
    $Log->FileLogging( 1 ); #Or anything greater
    
    #These will all disable the option
    $Log->FileLogging( '' );
    $Log->FileLogging( '0' );
    $Log->FileLogging( 0 );



=head4 ConsoleLogging I<(Default: C<true>)>

The C<ConsoleLogging> property of C<$Log> controls whether or not logging to standard output will occur. If enabled all logging events that are not filtered
will be output to the standard output stream.

The console logging option can be altered by passing any parameter that will equate to C<true> or C<false> in a standard expression.

    #These will all enable the option
    $Log->ConsoleLogging( "i'm not empty" ); #Or any other string that isn't empty and isn't a lone '0'
    $Log->ConsoleLogging( 1 ); #Or anything greater
    
    #These will all disable the option
    $Log->ConsoleLogging( '' );
    $Log->ConsoleLogging( '0' );
    $Log->ConsoleLogging( 0 );



=head4 ConsoleTimestamp I<(Default: C<false>)>

The C<ConsoleTimestamp> property of C<$Log> controls whether or not logging operations directed to standard output
will include a timestamp prefix.

This is normally not desirable as it can very quickly make the lines too long for the buffer and cause wrapping
Not to mention, output to the console is for human eyes at the time that it is occuring. There are already several
other generally accepted mechanisms in place which allow us to determine the approximate current time.
Such as looking out the window... I<(Note: That thing hurting your eyes; is the sun)>

Like other boolean properties in the Logger class this one can be altered by passing any parameter that will
equate to C<true> or C<false> in a standard conditional expression.



=head4 FilePath I<(Default: C<"I<timestamp>.log">)>

The C<FilePath> property sets the path to the log file that will be used to write all unfiltered logging events when C<FileLogging> is enabled.
Environment variables used when specifying the path will be expanded when setting a value. In the event that a non-existent environment variable
is specified the variable markers will be stripped from the name and it will be used instead.
I<The logic here being is that a deeper folder structure within the specified path would be more desirable on failure than trying to make
a new folder lower in the path which is more likely to run into permission issues or make directories in places they aren't wanted.>

    #Both Windows and *nix environment variables are expanded
    $Log->FilePath("%USERPROFILE%\Logs\Program.log");
    $Log->FilePath('$HOME/logs/program.log'); #Careful with *nix variables in interpolated strings.
    
    #If you ask for an environment variable that doesn't exist the name will be used instead
    $Log->FilePath("%USERPROFILE%\%LogDir%\Program.log"); #If %LogDir% doesn't exist
    #Result: "C:\Users\me\LogDir\Program.log";
    
    #On Windows systems the root directory is checked as well, if it doesn't exist a warning will be issued.
    #The value will still be set though, working under the premises that you have a reason to your rhyme.
    $Log->FilePath("Z:\Logs\Program.log");
    #warning: Logger: Invalid root directory in path! I hope you know what you're doing...

Relative paths are accepted as well but currently their expansion relies on the underlying system's ability to translate them. This typically
works just fine, but problems may occur if you try and bounce around in non-existent folders.
I<(A future version will likely remedy this by walking the theoretical path and accounting for back-steps within a non-existent path.)>

If no value is set to C<FilePath> file logging will generate a file named as C<"I<timestamp>.log"> in the current working directory.




=head4 NewLine

The C<NewLine> property reports on the current state of the logging marker. If a line is left in an unterminated state C<NewLine> will be C<false>.
If the last operation terminated the line it will be C<true>.

This can be useful when you are doing a series of appending writes like marking progress with C<.>'s and you want to figure out if you need
to terminate the line before continuing on with a fresh one after the progress output has finished.

    $Log->Write("Waiting for workers to finish, Please wait");
    my $Start = time();
    while(threads->list('threads::running')){
      $Log->Write('.');
      sleep 1;
      if(time() > $Start + 300){ #five minutes have passed
        threads->list('threads::running')->kill('STOP'); #Tell the workers to stop
        $Log->Debug("Threads exceeded time allowance, execution halted."); #This sends a newline character
      }
    }#while
    
    if(! $Log->NewLine ){
      $Log->WriteLine("");
    }




=head4 MaxSize I<(Default: C<5242880> IE: 5Mb)>

The C<MaxSize> property Sets or Gets the value used to determine if a log file being checked by C<Cleanup> has grown large enough to be
reset I<(and possibly archived)>.

The size can be specified either in the way of a raw number which will be interpreted as bytes, or by a string with a size identifier as a
suffix. The return value is always specified in bytes.

    #Size can be specified as a string with an identifying suffix
    $Log->MaxSize(1048576); #No translation necessary, this is 1Mb specified in bytes
    $Log->MaxSize('1048576b'); #Same as above
    $Log->MaxSize('600Kb'); #Translates the value from Kb to b
    $Log->MaxSize('5Mb'); #Translates the value from Mb to b (1:1,048,576b)
    $Log->MaxSize('.5Gb'); #I think you get the idea, but while we're on the topic; why would you this?
    $Log->MaxSize('1Tb'); #I'm honestly not even sure why added this as an option.




=head4 ArchiveLogs I<(Default: C<true>)>

The C<ArchiveLogs> property of C<$Log> controls whether or not a log file that is found to exceed C<MaxSize> during a C<Cleanup> process will
be archived before being emptied. I<(See the C<Cleanup> method documentation for more information)>

The archive option can be altered by passing any parameter that will equate to C<true> or C<false> in a standard expression.

    #These will all enable the option
    $Log->ArchiveLogs( "i'm not empty" ); #Or any other string that isn't empty and isn't a lone '0'
    $Log->ArchiveLogs( 1 ); #Or anything greater
    
    #These will all disable the option
    $Log->ArchiveLogs( '' );
    $Log->ArchiveLogs( '0' );
    $Log->ArchiveLogs( 0 );




=head2 Methods:

=head3 Direct Logging:

Utilizing the direct logging methods gives you the ability to write partial lines and continue adding to them through subsequent calls.
The object tracks the line state internally and takes care of prefixing new lines and closing old ones.
(if the text passed to the logging methods contain new line characters they are removed to not jumble the output)



=head4 Write( C<string $Text> )

Writes an unterminated line to any enabled streams. If the last operation included a line termination then a line prefix is added to the text.
I<(Write() will continue to append to the same line until a call to WriteLine() is made which will close out the line.)>




=head4 WriteLine( C<string $Text> )

Writes a terminated line to any enabled streams. If the last operation performed did not include a line termination the text will be appended
to the existing line and a prefix will not be attached.




=head4 WriteBlankLines( C<integer $Count> )

Writes I<n> blank lines to any enabled streams. If an unterminated line exists it will be terminated automatically before processing the
blank line write operations. I<(Note: Blank lines do not include a prefix.)>




=head3 Conditional Logging:

The conditional logging methods allow you to issue log commands to a particular level which will only be displayed if that level
is enabled. I<(All levels but Debug are enabled by default)>
This removes some of the logic needed when creating debug entries since you don't need to check if debug mode is enabled before
issuing the log command. it will be transparnetly dropped if that level is not enabled.

    $Log->Info("Something interesting happend");
    if( ! $EverythingWentWell ){
      $Log->Warn("This shouldn't have happend but it isn't that bad i guess...");
    }
    
    if( $ThingsArentGood ){
      $Log->Error("Something dun gone wrong here buddy");
    }
    
    if( $ThisIsDownRightBad ){
      $Log->Fatal("Blarggg i be dead me matee'!");
      $Log->Debug("Why did i think it would be a good idea to divide by zero?.");
    }



=head4 Info( C<string $Text> )

Writes a terminated line to any enabled streams and prefixes them with C<"Info: "> if the C<LOG_INFO> level is enabled.



=head4 Warn( C<string $Text> )

Writes a terminated line to any enabled streams and prefixes them with C<"Warning: "> if the C<LOG_WARN> level is enabled.



=head4 Error( C<string $Text> )

Writes a terminated line to any enabled streams and prefixes them with C<"Error: "> if the C<LOG_ERROR> level is enabled.



=head4 Fatal( C<string $Text> )

Writes a terminated line to any enabled streams and prefixes them with C<"Fatal Error: "> if the C<LOG_FATAL> level is enabled.




=head3 File Maintenance:


=head4 Cleanup( C<boolean $Backup> )

Checks the size of the log file found at C<FilePath> I<(If it exists)> against the specified maximum allowed size specified by C<MaxSize>.
If the file is above the threshold it will be cleaned out.
If C<Archive> property is C<true> the file will be archived as "FilenameI<-timestamp>.ext" in the same directory as the original prior to the
cleaning operation.

If the I<Optional> C<$Backup> argument is provided it will take precidence over the C<Archive> value. C<$Backup> uses Perl's built-in
logic to determine if the value is C<true> or C<false>, so anything that would equate in a standard C<if()> statement will do.

I<C<Cleanup> is called any time a value is set to C<FilePath> automatically, but you can call it any time you wish.>




=head1 SEE ALSO

Extension class for event driven logging in a graphical interface I<(not complete)>

=cut