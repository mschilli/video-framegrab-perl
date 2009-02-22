######################################################################
# Makefile.PL for FrameGrab
# 2009, Mike Schilli <cpan@perlmeister.com>
######################################################################
use ExtUtils::MakeMaker;
WriteMakefile(
    'NAME'         => 'Video::FrameGrab',
    'VERSION_FROM' => 'FrameGrab.pm', # finds $VERSION
    'EXE_FILES'    => ['eg/video-framegrab'],
    'PREREQ_PM'    => {}, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM => 'FrameGrab.pm',
       AUTHOR     => 'Mike Schilli <cpan@perlmeister.com>') : ()),
);
