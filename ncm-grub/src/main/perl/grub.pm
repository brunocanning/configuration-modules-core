# ${license-info}
# ${developer-info}
# ${author-info}

#
# grub - NCM grub configuration component
#
# set the correct kernel in /etc/grub.conf using grubby
#
###############################################################################

package NCM::Component::grub;

#
# a few standard statements, mandatory for all components
#

use strict;
use warnings;
use Fcntl qw(SEEK_SET);
use CAF::FileEditor;
use CAF::FileWriter;
use NCM::Component;
use Readonly;
use EDG::WP4::CCM::Element;
use vars qw(@ISA $EC);
@ISA = qw(NCM::Component);
$EC=LC::Exception::Context->new->will_store_all;
$NCM::Component::grub::NoActionSupported = 1;

Readonly my $PATH_KERNEL_VERSION => '/system/kernel/version';
Readonly my $PATH_CONSOLE_SERIAL => '/hardware/console/serial';
Readonly my $PATH_GRUB_KERNELS   => '/software/components/grub/kernels';
Readonly my $GRUB_CONF           => '/boot/grub/grub.conf';

sub parseKernelArgs {
    my ($kernelargs)=@_;

    ## howto remove an argument: precede with a -
    my @allargs=split(/ /,$kernelargs);
    my $kernelargsadd = "";
    my $kernelargsremove = "";
    my $i;
    foreach $i (@allargs) {
        if ($i =~ /^-/) {
            $i =~ s/^-//;
            $kernelargsremove .= $i." ";
        } else {
            $kernelargsadd .= $i." ";
        }
    }

    if ($kernelargsadd ne "") {
        chop($kernelargsadd);
    }
    if ($kernelargsremove ne "") {
        chop($kernelargsremove);
    }

    return ($kernelargsadd, $kernelargsremove);
}

sub grubbyArgsOptions {
    my ($kernelargs, $mb)=@_;
    my ($kernelargsadd, $kernelargsremove) = parseKernelArgs($kernelargs);

    if ($kernelargsadd ne "") {
#        chop($kernelargsadd);
        $kernelargsadd = "--".$mb."args=\"".$kernelargsadd."\"";
    }
    if ($kernelargsremove ne "") {
#        chop($kernelargsremove);
        $kernelargsremove = "--remove-".$mb."args=\"".$kernelargsremove."\"";
    }

    return ($kernelargsadd, $kernelargsremove);

}

sub password {
    my ($self, $config, $grub_fh) = @_;

    my $password;
    my $passwordpath = $self->prefix . "/password";

    # if passwords have not been explicitly enabled or disabled then do nothing.
    return unless ($config->elementExists($passwordpath));
    my $tree = $config->getElement($passwordpath)->getTree();

    if (!defined($tree->{enabled})) {
        $self->verbose("password section defined, but enabled/disabled not set");
        return;
    } elsif (!$tree->{enabled}) {
	$self->info("removing grub password");
        $grub_fh->remove_lines(qr/^password\s+/, '');
        return;
    }

    if (my $passwordfile = $tree->{file}) {
        my $fileuser = $tree->{file_user};
        if (! -R $passwordfile) {
            $self->error("grub password file $passwordfile does not exist or is not readable.");
            return;
        }
        my $pf_fh = CAF::FileEditor->new($passwordfile, log => $self);
        $pf_fh->cancel();
        foreach my $line (split(/\n/, "$pf_fh")) {
            chomp $line;
            my @fields = split(/:/, $line, 2);
            if ($fields[0] eq $fileuser) {
                $password = $fields[1];
                last;
           }
        }
        if (!defined($password)) {
            $self->error("unable to find user $fileuser in grub password file $passwordfile");
            return;
        }
    } else {
        $password = $tree->{password};
    }

    my $val = $tree->{option} ? "--$tree->{option} " : "";
    $val .= $password;

    $grub_fh->add_or_replace_lines(qr/^password\s+/,
                              qr/^password $val$/,
                              "password $val\n",
                              $self->main_section_offset($grub_fh),
                              );
}

# get the position for the main section
# ie. after the header comments
sub main_section_offset {
    my ($self, $fh) = @_;
    my ($start, $end) = $fh->get_header_positions();
    return $start == -1 ? BEGINNING_OF_FILE : (SEEK_SET, $end);
}

##########################################################################
sub Configure {
##########################################################################
  my ($self,$config)=@_;

  my $grubby = '/sbin/grubby';
  my $prefix = '/boot';
  if ($config->elementExists("/software/components/grub/prefix")) {
    $prefix = $config->getValue("/software/components/grub/prefix");
  }
  my $kernelname = 'vmlinuz';
  my $kernelversion = '';
  if ( $config->elementExists($PATH_KERNEL_VERSION) ) {
      $kernelversion = $config->getValue($PATH_KERNEL_VERSION);
  };
  my $fulldefaultkernelpath;
  # An undefined kernel version or an empty string are treated equally
  if ( !$kernelversion ) {
      $self->debug(1,"No kernel version defined: default kernel will not be set");
  } else {
      $fulldefaultkernelpath = $prefix.'/'.$kernelname.'-'.$kernelversion;
  }

  my $grub_fh = CAF::FileEditor->new($GRUB_CONF,
                                owner => "root",
                                group => "root",
                                mode => 0400,
                                log => $self);

  if (!"$grub_fh") {
      print $grub_fh "# Generated by ncm-grub\n";
  }
  
  my $cons = undef;
  if ($config->elementExists($PATH_CONSOLE_SERIAL)) {
    my %consnode = $config->getElement($PATH_CONSOLE_SERIAL)->getHash();
    my $unit = "0";
    if (exists $consnode{"unit"}) {
      $unit = $consnode{"unit"}->getValue();
    }

    my $speed = "9600";
    if (exists $consnode{"speed"}) {
      $speed = $consnode{"speed"}->getValue();
    }

    my $word = "8";
    if (exists $consnode{"word"}) {
      $word = $consnode{"word"}->getValue();
    }

    my $parity = "n";
    if (exists $consnode{"parity"}) {
      $parity = $consnode{"parity"}->getValue();
    }

    $cons = " console=ttyS$unit,$speed$parity$word";
    my $serial   = "--unit=$unit --speed=$speed --parity=$parity --word=$word";
    my $terminal = "serial console";

    $grub_fh->add_or_replace_lines(qr/^serial\s*/,
                              qr/^serial $serial$/,
                              "serial $serial\n",
                              $self->main_section_offset($grub_fh),
                              );

    $grub_fh->add_or_replace_lines(qr/^terminal\s*/,
                              qr/^terminal $terminal$/,
                              "terminal $terminal\n",
                              $self->main_section_offset($grub_fh),
                              );
  }

  $self->password($config, $grub_fh);
  $grub_fh->close();

  my @kernels;

  # read information in as array of hashes
  if ($config->elementExists($PATH_GRUB_KERNELS)) {
      my $configroot = $config->getElement($PATH_GRUB_KERNELS);

      while ($configroot->hasNextElement()) {
          my $el = $configroot->getNextElement();
          my $eln = $el->getName();
          $self->verbose ("Element: $eln");
          if ($el->isType(EDG::WP4::CCM::Element::NLIST)) {
              my %kernelhash = $el->getHash();
              $kernels[$eln]=\%kernelhash;

              while( my ($k, $v) = each %kernelhash ) {
                  if ($v->isProperty()) {
                      my $value = $v->getValue();
                      $kernelhash{$k}=$value;
                      $self->verbose("  key: $k, value $value");
                  }
              }
          }
      }
  }


# check to see whether grubby has native support for configuring
# multiboot kernels
  my $check_grubby_mbsupport=`$grubby --add-multiboot 2>&1`;
  chomp($check_grubby_mbsupport);

  my $grubby_has_mbsupport;

  if ("$check_grubby_mbsupport" eq "grubby: bad argument --add-multiboot: missing argument") {
      $grubby_has_mbsupport=1;
      $self->verbose("This version of grubby has support for multiboot kernels");
  } else {
      $grubby_has_mbsupport=0;
      $self->verbose("This version of grubby has no support for multiboot kernels");
  }

  foreach my $kernel (@kernels) {

      my ($kernelpath, $kernelargs, $kerneltitle, $kernelinitrd,
          $multibootpath, $fullkernelpath, $fullkernelinitrd, $fullmultibootpath,$mbargs);

      if ($kernel->{'kernelpath'}) {
          $kernelpath=$kernel->{'kernelpath'};
          $fullkernelpath=$prefix.$kernelpath;
      }
      else {
          $self->error("Mandatory kernel path missing, skipping this kernel");
          next;
      }

      if ($kernel->{'kernelargs'}) {
          $kernelargs=$kernel->{'kernelargs'};
          if ($cons) {
              # by $cons we mean serial cons, so we should only sub serial entries.
              $kernelargs =~ s{console=(ttyS[^ ]*)}{};
              $kernelargs .= $cons;
          }
      }

      if ($kernel->{'title'}) {
          $kerneltitle=$kernel->{'title'};
      }
      else {
          $kerneltitle=$kernelpath;
      }

      if ($kernel->{'initrd'}) {
          $kernelinitrd=$kernel->{'initrd'};
          $fullkernelinitrd=$prefix.$kernel->{'initrd'};
      }
      if ($kernel->{'multiboot'}) {
          $multibootpath=$kernel->{'multiboot'};
          $fullmultibootpath=$prefix.$kernel->{'multiboot'};

      }
      if ($kernel->{'mbargs'}) {
          $mbargs=$kernel->{'mbargs'};
      }

      my $grubbystring="";



      # check whether this kernel is already installed
      `$grubby --info=$fullkernelpath 2>&1`;
      my $kernelinstalled = $?;

      # check whether the multiboot loader is installed
      my $mbinstalled=1;
      if ($multibootpath) {
          `$grubby --info=$fullmultibootpath 2>&1`;
          $mbinstalled= $?;
      }

      if ($kernelinstalled && $mbinstalled) {
          $self->info ("Kernel $kernelpath not installed, trying to add it");

          # installing multiboot loader
          if ($kernel->{'multiboot'}) {
              if (!$grubby_has_mbsupport) {
                  $self->info ("This version of grubby doesn't support multiboot");

                  # in this case, we write out the whole entry ourselves
                  # as it is easier than working round grubby
                  my ($kernelargsadd, $kernelargsremove, $mbargsadd, $mbargsremove);

                  if ($kernelargs) {
                      ($kernelargsadd, $kernelargsremove) = parseKernelArgs($kernelargs);
                  }
                  if ($mbargs) {
                      ($mbargsadd, $mbargsremove) = parseKernelArgs($mbargs);
                  }

                  my $grubconfstring="title $kerneltitle\n";
                  $grubconfstring.="\tkernel $multibootpath $mbargsadd\n";
                  $grubconfstring.="\tmodule $kernelpath $kernelargs\n";
                  $grubconfstring.=($kernelinitrd)?"\tmodule $kernelinitrd":"";
                  $self->verbose("Generating grub entry ourselves: \n$grubconfstring");


                  # append this entry to grub.conf
                  #
                  my $grubconf_fh = CAF::FileWriter->new($GRUB_CONF, log => $self);
                  print $grubconf_fh $grubconfstring;
                  $grubconf_fh->close();

              } else {
                  $self->verbose("Adding kernel using native grubby multiboot support");
                  my ($mbargsadd, $mbargsremove, $kernelargsadd, $kernelargsremove);

                  $grubbystring.=" --add-multiboot=\"$fullmultibootpath\"";

                  if ($kernelargs) {
                      ($kernelargsadd, $kernelargsremove) = parseKernelArgs($kernelargs);
                  }
                  if ($mbargs) {
                      ($mbargsadd, $mbargsremove) = parseKernelArgs($mbargs);
                  }

                  $grubbystring.=($mbargsadd)?" --mbargs=\"$mbargsadd\"":"";
                  $grubbystring.=($mbargsremove)?" --remove-mbargs=\"$mbargsremove\"":"";

                  $grubbystring.=" --add-kernel=\"$fullkernelpath\"";

                  $grubbystring.=($kernelargsadd)?" --args=\"$kernelargsadd\"":"";
                  $grubbystring.=($kernelargsremove)?" --args=\"$kernelargsremove\"":"";

                  $grubbystring.=" --title=\"$kerneltitle\"";
                  $grubbystring.=($kernelinitrd)?" --initrd=\"$fullkernelinitrd\"":"";

                  $self->verbose("Configuring kernel using grubby command: $grubbystring");
                  my $grubbyresult=`$grubby $grubbystring 2>&1`;
              }

          } else {
              $self->info("Adding new standard kernel");
              $grubbystring.=" --add-kernel=\"$fullkernelpath\"";

              my ($kernelargsadd, $kernelargsremove);
              if ($kernelargs) {
                  ($kernelargsadd, $kernelargsremove) = parseKernelArgs($kernelargs);
              }

              $grubbystring.=($kernelargsadd)?" --args=\"$kernelargsadd\"":"";
              $grubbystring.=($kernelargsremove)?" --remove-args=\"$kernelargsremove\"":"";

              $grubbystring.=" --title=\"$kerneltitle\"";
              $grubbystring.=($kernelinitrd)?" --initrd=\"$fullkernelinitrd\"":"";
              $self->verbose("Adding kernel using grubby command: $grubbystring");
              my $grubbyresult=`$grubby $grubbystring 2>&1`;
          }
      }
      else {  # updating existing kernel entry

          $self->info ("Updating installed kernel $kernelpath");

          if ($kernel->{"multiboot"}) {

              if ($grubby_has_mbsupport) {
                  $self->verbose("Updating kernel using native grubby multiboot support");
                  $grubbystring.=" --add-multiboot=\"$fullmultibootpath\"";

                  $grubbystring.=" --update-kernel=\"$fullkernelpath\"";

                  my ($kernelargsadd, $kernelargsremove, $mbargsadd, $mbargsremove);

                  if ($kernelargs) {
                      ($kernelargsadd, $kernelargsremove) = parseKernelArgs($kernelargs);
                  }
                  if ($mbargs) {
                      ($mbargsadd, $mbargsremove) = parseKernelArgs($mbargs);
                  }

                  $grubbystring.=($mbargsadd)?" --mbargs=\"$mbargsadd\"":"";
                  $grubbystring.=($mbargsremove)?" --remove-mbargs=\"$mbargsremove\"":"";


                  $grubbystring.=($kernelargsadd)?" --args=\"$kernelargsadd\"":"";
                  $grubbystring.=($kernelargsremove)?" --remove-args=\"$kernelargsremove\"":"";

                  $self->verbose("Updating kernel using grubby command: $grubbystring");
                  my $grubbyresult=`$grubby $grubbystring 2>&1`;

              } else {
                  $self->warn("Updating multiboot kernel using non-multiboot grubby: check results");
                  $grubbystring.=" --update-kernel=\"$fullmultibootpath\"";

                  my ($mbargsadd, $mbargsremove);

                  if ($mbargs) {
                      ($mbargsadd, $mbargsremove) = parseKernelArgs($mbargs);
                  }

                  $grubbystring.=($mbargsadd)?" --args=\"$mbargsadd\"":"";
                  $grubbystring.=($mbargsremove)?" --remove-args=\"$mbargsremove\"":"";


                  # TODO: use NCM::Check::lines to try and
                  # edit the module args lines?


                  my $grubbyresult=`$grubby $grubbystring 2>&1`;
              }

          }
          else {

              $self->verbose("Updating standard kernel $kernelpath");
              my ($kernelargsadd, $kernelargsremove);
              if ($kernelargs) {
                  ($kernelargsadd, $kernelargsremove) = parseKernelArgs($kernelargs);
              }
              $grubbystring.=($kernelargsadd)?" --args=\"$kernelargsadd\"":"";
              $grubbystring.=($kernelargsremove)?" --remove-args=\"$kernelargsremove\"":"";

              $grubbystring.=" --update-kernel=\"$fullkernelpath\"";
              my $grubbyresult=`$grubby $grubbystring 2>&1`;
          }
      }

  }



  # next section of code processes the default kernel as defined in
  # /system/kernel/version and comes from the earlier version of ncm-grub

  my $oldkernel=undef;

  unless (-x $grubby) {
      $self->error ("$grubby not found");
      return;
  }
  if ( defined($fulldefaultkernelpath) && !-e $fulldefaultkernelpath) {
      $self->error ("Kernel $fulldefaultkernelpath not found");
      return;
  }


  # the checks that grub uses to determine whether a kernel is "good"
  # are simplistic, and include checking that the name is like "vmlinuz"
  # so we disable them for now
  $oldkernel=`$grubby --default-kernel --bad-image-okay`;
  chomp($oldkernel);
  if ($?) {
      $self->error ("Can't run $grubby --default-kernel, (return code $?)");
      return;
  }

  if ($oldkernel eq '') {
      $self->warn ("Can't get current default kernel");
  }


  unless ($NoAction) {
      if ( !defined($fulldefaultkernelpath) || ($oldkernel eq $fulldefaultkernelpath) ) {
          my $kernel_version_str = "($kernelversion)" if $kernelversion;
          $self->info("correct kernel $kernelversion already configured");
          $fulldefaultkernelpath = $oldkernel unless defined($fulldefaultkernelpath);
      } else {
          my $s=`$grubby --set-default $fulldefaultkernelpath`;

          if ($?) {

              $s=`$grubby --set-default $oldkernel` unless ($oldkernel eq '');
              $self->error("can't run $grubby --set-default $fulldefaultkernelpath, reverting to previous kernel $oldkernel");
              return;
          }

          # check that new kernel is really set
          # as grubby always returns 0 :-(
          #
          $s=`$grubby --default-kernel --bad-image-okay`;
          chomp($s);
          if ($s ne $fulldefaultkernelpath) {
              # check whether the specified kernel version exists within
              # another multiboot specification
              foreach my $kernel (@kernels) {

                  if ( ($prefix.($kernel->{"kernelpath"})) eq $fulldefaultkernelpath) {
                      my $fullmultibootpath=$prefix.($kernel->{"multiboot"});
                      $self->verbose("Trying to set kernel to $fullmultibootpath");
                      $s=`$grubby --set-default $fullmultibootpath`;

                      $s=`$grubby --default-kernel --bad-image-okay`;
                      chomp($s);

                      if ($s ne $fullmultibootpath) {
                          $s=`$grubby --set-default $oldkernel` unless ($oldkernel eq '');
                          $self->error ("Can't run $grubby --set-default $fulldefaultkernelpath, reverting to previous kernel $oldkernel");
                          return;
                      }
                  }
              }
          }
      }

      ## at this point the `$grubby --default-kernel` should equal $fulldefaultkernelpath

      # Check if 'fullcontrol' is defined in CDB
      my $fullcontrol = 0;
      if ( $config->elementExists("/software/components/grub/fullcontrol")
          && ($config->getValue("/software/components/grub/fullcontrol") eq "true")){
	  $fullcontrol = 1;
	  $self->debug(2,"fullcontrol is true");
      }
      else{
	  $self->debug(2,"fullcontrol is not defined or false");
      }

      # If we want full control of the arguments:
      if ( $fullcontrol ) {

	  my $kernelargspath="/software/components/grub/args";
	  my $kernelargsadd;
	  if ($config->elementExists($kernelargspath)) {
	      $kernelargsadd=$config->getValue($kernelargspath);
	  }
	  else{
	      $kernelargsadd="";
	  }

          ## Check current arguments
	  my $kernelargsremove;

	  my $info = `$grubby --info=$fulldefaultkernelpath`;
	  if($info =~ /args=\"(.*)\"\n/){
	      $kernelargsremove = $1;
	      print "\nKernelArgRemove", $kernelargsremove, "\n";
	  }

          ## Check if the arguments we want to add are the same we have
	  if ($kernelargsremove eq $kernelargsadd){
	      $self->OK("Updated boot kernel without changes in the arguments");
	  }
	  else{
	      ## Remove all the arguments
	      if ($kernelargsremove ne "") {
		  $kernelargsremove = "--remove-args=\"".$kernelargsremove."\"";
		  `$grubby --update-kernel=$fulldefaultkernelpath $kernelargsremove`;
		  if ($?) {
		      $self->error("can't run $grubby --update-kernel=$fulldefaultkernelpath $kernelargsremove");
		      return;
		  }
	      }

	      ## Add the specified inside $kernelargs
	      if ($kernelargsadd ne "") {
		  print "\nKernelArgAdd", $kernelargsadd, "\n";
		  $kernelargsadd = "--args=\"".$kernelargsadd."\"";
		  `$grubby --update-kernel=$fulldefaultkernelpath $kernelargsadd`;
		  if ($?) {
		      $self->error("can't run $grubby --update-kernel=$fulldefaultkernelpath $kernelargsadd");
		      return;
		  }
		  $self->OK("Updated boot kernel arguments with $kernelargsadd $kernelargsremove");
	      }

	      else {
		  $self->OK("Updated boot kernel with no arguments");
	      }
	  }
      } else {
          # If we want no full control of the arguments
	  my $kernelargspath="/software/components/grub/args";
	  if ($config->elementExists($kernelargspath)) {
	      my $kernelargs=$config->getValue($kernelargspath);
	      my ($kernelargsadd, $kernelargsremove) = grubbyArgsOptions($kernelargs,"");


	      my $s=`$grubby --update-kernel=$fulldefaultkernelpath $kernelargsadd $kernelargsremove`;
	      if ($?) {
		  $self->error("can't run $grubby --update-kernel=$fulldefaultkernelpath $kernelargsadd $kernelargsremove");
		  return;
	      }
	      ## since you can't check the current kernelargs with grubby, lets hope for the best?
	      $self->OK("Updated boot kernel ($fulldefaultkernelpath) arguments with $kernelargsadd $kernelargsremove");
	  } else {
	      $self->verbose("No kernel arguments set");
	  }
      }
  }
  return;
}

1; #required for Perl modules
