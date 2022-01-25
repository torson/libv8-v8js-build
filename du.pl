#!/usr/bin/perl

### examples
# ## sum size
# docker/du.pl -p=.
# docker/du.pl -p=. -v
# docker/du.pl -p=. -vm=logs

# docker-compose exec -T php-fpm bash -c "docker/du.pl -p=."
# docker-compose exec -T php-fpm bash -c "docker/du.pl -p=. -v"
# docker-compose exec -T php-fpm bash -c "docker/du.pl -p=. -vm=logs"

# ## all folder sizes
# # host
# FOLDERS=$(ls -al | grep drwx | awk '{print $NF}' | awk '{if(NR>2)print $1}' | while read folder ; do echo -n "$folder," ; done | sed 's/,$//')
# docker/du.pl -p=${FOLDERS} -s | awk '{printf "%0.0f\t%s\n", $1/1000, $2}'
# docker/du.pl -p=${FOLDERS} | awk '{printf "%0.0f\n", $1/1000}'
# # container
# docker-compose exec -T php-fpm bash -c "FOLDERS=\$(ls -al | grep drwx | awk '{print \$NF}' | awk '{if(NR>2)print \$1}' | while read folder ; do echo -n \"\$folder,\" ; done | sed 's/,\$//') ; docker/du.pl -p=\${FOLDERS} -s | awk '{printf \"%0.0f\t%s\n\", \$1/1000, \$2}' "
# docker-compose exec -T php-fpm bash -c "FOLDERS=\$(ls -al | grep drwx | awk '{print \$NF}' | awk '{if(NR>2)print \$1}' | while read folder ; do echo -n \"\$folder,\" ; done | sed 's/,\$//') ; docker/du.pl -p=\${FOLDERS} | awk '{printf \"%0.0f\n\", \$1/1000}' "


# NOTE: this script checks if there's docker-sync.yml in the passed folder path
#       and ignores subdirs that match sync_excludes parameter in docker-sync.yml

use strict;
use warnings;

my @aPaths;
my @aIgnorePaths;
my %hIgnorePathsRegex;
my $argCalcTotal = 1;
my $verbose = 0;
my $verboseMatch = "";

my $inErr = "";
my $err = "";
my $help = "";

$help .= "\nWRONG ARGUMENT INPUT!  Exiting..";
$help .= "\n\nUsage:\n$0 OPTIONS\n\nOPTIONS:\n";
$help .= "\n\t-p=path1[,path2,...]          ; file or directory path(s), absolute or relative";
$help .= "\n\t-ip=path1[,path2,...]         ; ignore subpaths inside paths ";
$help .= "\n\t-s                            ; split output size for each set path";
$help .= "\n\t-v                            ; verbose, print info output during processing";
$help .= "\n\t-vm                           ; verbose but match only specific paths, print info output during processing";
$help .= "\n\nEXAMPLE: \n\t$0 -p=/var/log -ip=monit   ; calculate size of /var/log and ignore subfolder monit (/var/log/monit)";
$help .= "\n\nEXAMPLE: \n\t$0 -p=log,/var/lib -ip=monit,php";
$help .= "\n\n";

## ARGUMENTS FETCH

for (my $iargv=0; $iargv<=$#ARGV; $iargv++) {
     my @param;
     if ($ARGV[$iargv] =~ m/^\-p\=/i) {
           @param = split(/=/, $ARGV[$iargv]);
           @aPaths = split(/,/,$param[1]);
     }
     elsif ($ARGV[$iargv] =~ m/^\-ip\=/i) {
           @param = split(/=/, $ARGV[$iargv]);
           @aIgnorePaths = split(/,/,$param[1]);
     }
     elsif ($ARGV[$iargv] =~ m/^\-s$/i) {
           $argCalcTotal = 0;
     }
     elsif ($ARGV[$iargv] =~ m/^\-v$/i) {
           $verbose = 1;
     }
     elsif ($ARGV[$iargv] =~ m/^\-vm\=/i) {
           $verbose = 1;
           @param = split(/=/, $ARGV[$iargv]);
           $verboseMatch = $param[1];
     }
     else {
           print $help;
           exit;
     }
}

if (scalar(@ARGV)==0) {
     $inErr .= "\n  Error! No input arguments. \n";
}

foreach my $path (@aPaths) {
     if (!(-e $path)) {
          $inErr .= "\n Error! path doesn't exist: $path";
     }
}

if ($inErr ne "") {
     print $inErr . "\n" .$help;
     exit;
}

my $out='';
my %sizes_H;
my $maxSizeLength=0;
my $totalSize=0;

foreach my $path (@aPaths) {
     if (-d $path) {
          if ($argCalcTotal) {
               useDockerSyncConf($path);
               $totalSize += dirSize($path, $path);
          }
          else {
               $sizes_H{$path} = dirSize($path, $path);
          }
     }
     else {
          if ($argCalcTotal) {
               $totalSize += (stat($path))[7];
          }
          else {
               $sizes_H{$path} = (stat($path))[7];
          }
     }
}

if ($argCalcTotal) {
     $out .= $totalSize . "\n";
}
else {
     foreach my $path (keys(%sizes_H)) {
          my $sizeLength = length($sizes_H{$path});
          if ($sizeLength>$maxSizeLength) {
               $maxSizeLength = $sizeLength;
          }
     }

     foreach my $path (sort(keys(%sizes_H))) {
          my $spaces='';
          my $pathSizeLength = length($sizes_H{$path});
          for (my $i=$pathSizeLength+1; $i<=$maxSizeLength; $i++) {
               $spaces .= " ";
          }
          $spaces .= "    ";

          $out .= $sizes_H{$path} . $spaces . $path . "\n";
     }
}
print $out;

## SUBS

sub dirSize {
     my($dir, $dirOrig)  = @_;
     my($size) = 0;
     my($fd);

     foreach my $ignorePath (@aIgnorePaths) {
          my $dirOrigEsc = regExEscape($dirOrig);
          my $ignorePathEsc= regExEscape($ignorePath);
          if ($hIgnorePathsRegex{$ignorePath}) {
               $ignorePathEsc = $ignorePath;
          }
          if ($verbose && $verboseMatch) {
               if ($dir =~ m!$verboseMatch!) {
                    print "pre-ignore; \$dir=$dir, \$dirOrig=$dirOrig, \$dirOrig/\$ignorePath=$dirOrig/$ignorePath, \$dirOrigEsc/\$ignorePathEsc=$dirOrigEsc\\/$ignorePathEsc \n"; 
               }
          }
          if ($dir =~ m!$dirOrigEsc/$ignorePathEsc$!) {
               if ($verbose) { print "ignoring; \$dirOrig=$dirOrig, \$dirOrig/\$ignorePath=$dirOrig/$ignorePath, \$dirOrigEsc/\$ignorePathEsc=$dirOrigEsc\\/$ignorePathEsc \n"; }
               return(0);
          }
     }

     opendir($fd, $dir) or die "$!";

     for my $item ( readdir($fd) ) {
          next if ( $item =~ /^\.\.?$/ );

          my($path) = "$dir/$item";

          if (! -l $path) {
               $size += ((-d $path) ? dirSize($path, $dirOrig) : (-f $path ? (stat($path))[7] : 0));
          }
     }

     closedir($fd);

     return($size);
}

sub useDockerSyncConf {
     # automaticaly ignore paths defined in docker-sync.yml under sync_excludes parameter
     my($path)  = @_;
     my $dockerSyncConfFile = "$path/docker-sync.yml";
     if (-f $dockerSyncConfFile) {
          open(FILE, "$dockerSyncConfFile") or die "Can't open $dockerSyncConfFile for read: $!";
          my @aContent = <FILE>;
          close(FILE);
          my $syncExludesLine="";
          my $syncExludesTypeLine="";
          foreach my $line (@aContent) {
               if ($line =~ m/^\s*sync_excludes:\s*\[[^]]+\]/i) {
                    $syncExludesLine = $line;
               }
               elsif ($line =~ m/^\s*sync_excludes_type:/i) {
                    $syncExludesTypeLine = $line;
               }
          }
          if ($syncExludesLine) {
               $syncExludesLine =~ s!^\s*sync_excludes:\s*\[['|"]!!;
               $syncExludesLine =~ s!['|"]\].*!!;
               $syncExludesLine =~ s!,\s!,!g;
               chomp $syncExludesLine;
               my @syncExcludes = split(/['|"],['|"]/, $syncExludesLine);
               if ($syncExludesTypeLine =~ m/regex/i) {
                    if ($verbose) { print "sync_excludes_type is set to Regex\n"; }
                    foreach my $syncExclude (@syncExcludes) {
                         if ($verbose) { print "$syncExclude\n"; }
                         # if ($verbose) { print "removing starting ^ as otherwise there is no match together with \$dirOrig in dirSize()\n"; }
                         $syncExclude =~ s!^\^!!;
                         # if ($verbose) { print "removing starting / as otherwise there is no match together with \$dirOrig in dirSize()\n"; }
                         $syncExclude =~ s!^/!!;
                         if ($verbose) { print "$syncExclude\n"; }
                         # if ($verbose) { print "removing trailing /* (last path component) as sync_excludes can have some pattern set for last path component because we want empty folder to be copied, but it clashes with the regex match with \$dir in dirSize()\n"; }
                         $syncExclude =~ s!\\?/[^/]+$!!;
                         if ($verbose) { print "$syncExclude\n"; }
                         $hIgnorePathsRegex{$syncExclude}++;
                    }
               }
               if ($verbose) { print "removing trailing / as otherwise there is no match with the folder name in dirSize()\n"; }
               foreach my $syncExclude (@syncExcludes) {
                    $syncExclude =~ s!/$!!;
                    if ($verbose) { print "$syncExclude\n"; }
               }
               push(@aIgnorePaths, @syncExcludes);
          }
     }
}

sub regExEscape {

        my ($string) = @_;

        ## special characters: '^,$,(,),<,>,[,{,\,|,/,.,*,+,?'
        ## first escape backslash
        $string =~ s!\\!\\\\!g;
        ## now all others
        $string =~ s!\^!\\\^!g;
        $string =~ s!\$!\\\$!g;
        $string =~ s!\(!\\\(!g;
        $string =~ s!\)!\\\)!g;
        $string =~ s!\<!\\\<!g;
        $string =~ s!\>!\\\>!g;
        $string =~ s!\[!\\\[!g;
        $string =~ s!\{!\\\{!g;
        $string =~ s!\|!\\\|!g;
        $string =~ s!\/!\\\/!g;
        $string =~ s!\.!\\\.!g;
        $string =~ s!\*!\\\*!g;
        $string =~ s!\+!\\\+!g;
        $string =~ s!\?!\\\?!g;

        return $string;
}
