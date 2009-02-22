######################################################################
# Makefile.PL for FrameGrab
# 2009, Mike Schilli <cpan@perlmeister.com>
######################################################################
use ExtUtils::MakeMaker;
WriteMakefile(
    'NAME'         => 'FrameGrab',
    'VERSION_FROM' => 'lib/FrameGrab.pm', # finds $VERSION
    'PREREQ_PM'    => {}, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM => 'lib/FrameGrab.pm',
       AUTHOR     => 'Mike Schilli <cpan@perlmeister.com>') : ()),
);
