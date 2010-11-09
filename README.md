# dist 1.1
    (c) 2009 Phil Christensen <phil@bubblehouse.org>

dist is a utility that helps automate code distribution across multiple
servers. It follows a relatively minimalist approach to distribution, and
relies primarily on ssh, scp and tar to get the job done. A user-configurable
list of filename exclusions speeds up file transfer, making this a great tool
for web developers. The default settings allow users to work more efficiently
when making various changes to code while large binary assets (i.e., images)
remain static.

Each local directory you configure with dist can use its own particular
default settings, so this is also useful for users with a large number of
projects deploying to even a server.

## Usage
    Usage: /usr/local/bin/dist [options]
    
    Options:
      Flags:
      -v, --svn         Upload only modified SVN status results.
      -f, --force-save  Save directory prefs, overwriting defaults.
      -S, --sudo        Use sudo to extract files on the remote server.
      -i, --ignore      Ignore tar exclude file.
      -D, --debug       Perform a dry-run and output the actions normally taken.
      -?, --help        Display this usage guide.
      
      Parameters:
      -s, --source      The source directory to distribute.    [required]
      -d, --dest        Where to put the files on the remote machines.    [required]
      -h, --host        The hosts to distrubute to.    [required]
      -u, --user        The user to connect to the hosts as. [default: root]   
      -o, --chown       Change the ownership of the files to this.    
      -p, --chmod       Change the file permissions to this.    


### About Excluding Files

When you first run dist (in any directory), it creates a file in
~/.dist-exclude with the following content:

     CVS
     .DS_Store
     *.txt
     *.zip
     *.doc
     *.pdf
     *.jpg
     *.gif
     *.wmv
     system.ini.php
     .#*

This is passed to tar as a list of files to exclude from the tarball. This
generally works without modification, but if you're uploading a site for the
first time, you probably want to remove the lines for *.jpg and *.gif.
