# Play Version Manager

## Credits

Credit should go, where the credit is due. This script is a fork of the excellent Node Version Manager, created by Tim Casswell 
and Matthew Ranney. NVM is available here: https://github.com/creationix/nvm.git. Latest changes will be pulled in, whenever it 
is feasible. Due to different code formatting and preferences this might turn out to be too hard in the long run. 

## Installation

The Play! Framework (http://www.playframework.org) is a Java and/or Scala web framework, so in order for it to work you will need to 
have Java tooling in place. Play! 1-series is purely Java-based, but can be extended to support Scala using a dedicated module.
Play! 2.x is mainly Scala based, so it is mandatory to have Scala tooling installed and in your path.

To install create a folder somewhere in your filesystem with the "`pvm.sh`" file inside it.  I put mine in a folder called "`~/utils/pvm`". 
The normal way of using .-prefixed directories unfortunately does not work well with Play. 
Having a separate directory for tools won't clutter your file listings, but is conveniently available when you need to access it.

Or if you have `git` installed, then just clone it:

    git clone git://github.com/kaiinkinen/pvm.git ~/utils/pvm

To activate pvm, you need to source it from your bash shell

    . ~/utils/pvm/pvm.sh

I always add this line to my ~/.bashrc or ~/.profile file to have it automatically sources upon login.   
Often I also put in a line to use a specific version of play.
    
## Usage

To download, compile, and install the 2.0 release of play, do this:

    pvm install 2.0


And then in any new shell just use the installed version:

    pvm use 2.0

Or you can just run it:

    pvm run 2.0

If you want to see what versions are available:

    pvm ls

To restore your PATH, you can deactivate it.

    pvm deactivate

To set a default Play version to be used in any new shell, use the alias 'default':

    pvm alias default 2.0

## Bash completion

To activate, you need to source `bash_completion`:

  	[[ -r $PVM_DIR/bash_completion ]] && . $PVM_DIR/bash_completion

Put the above sourcing line just below the sourcing line for PVM in your profile (`.bashrc`, `.bash_profile`).

### Usage

pvm

	$ pvm [tab][tab]
	alias          copy-packages  help           list           run            uninstall      version        
	clear-cache    deactivate     install        ls             unalias        use

pvm alias

	$ pvm alias [tab][tab]
	default

	$ pvm alias my_alias [tab][tab]
	1.2.3        1.2.4       2.0
	
pvm use

	$ pvm use [tab][tab]
	my_alias        default        1.2.3        1.2.4       2.0
	
pvm uninstall

	$ pvm uninstall [tab][tab]
	my_alias        default        1.2.3        1.2.4       2.0
	
## Problems

If you try to install a play version and the installation fails, be sure to delete the play downloads from src (~/.pvm/src/) or you might get an error when trying to reinstall them again or you might get an error like the following:
    
    curl: (33) HTTP server doesn't seem to support byte ranges. Cannot resume.


On a unix based systems you shouldn't install pvm in a hidden directory, e.g. ~/.pvm. The play copy_directory utility function disregards directories which start with a dot, including parent directories. 
Running play new-module will fail with a spectacular pyhon stack trace in this case. This applies at least to play 1.2.X, so it's safer to use some other installation directory, like ~/utils/pvm
