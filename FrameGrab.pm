###########################################
package Video::FrameGrab;
###########################################

use strict;
use warnings;
use Sysadm::Install qw(bin_find tap slurp blurt);
use File::Temp qw(tempdir);
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($DEBUG);

our $VERSION = "0.01";

###########################################
sub new {
###########################################
    my($class, %options) = @_;

    my $self = {
        mplayer => undef,
        tmpdir  => tempdir(CLEANUP => 1),
        %options,
    };

    if(! defined $self->{mplayer}) {
        $self->{mplayer} = bin_find("mplayer"),
    }

    if(! -x $self->{mplayer}) {
        LOGDIE "Fatal error: Can't find mplayer";
    }

    bless $self, $class;
}

###########################################
sub frame_grab {
###########################################
    my($self, $video, $time) = @_;

    my($stdout, $stderr, $rc) = 
        tap $self->{mplayer}, qw(-frames 1 -ss), $time, 
            "-vo", "jpeg:maxfiles=1:outdir=$self->{tmpdir}",
            $video;

    if($rc != 0) {
        ERROR "$stderr";
        return undef;
    }

    $self->{jpeg} = slurp("$self->{tmpdir}/00000001.jpg");
    return $self->{jpeg}
}

###########################################
sub jpeg_save {
###########################################
    my($self, $file) = @_;

    blurt $self->{jpeg}, $file;
}

1;

__END__

=head1 NAME

Video::FrameGrab - Grab a frame from a video

=head1 SYNOPSIS

    use Video::FrameGrab;

    my $grabber = Video::FrameGrab->new();

    my $jpg_data = $grabber->frame_grab( $avi_file, "00:00:10" );

    $grabber->jpeg_save("snapshot.jpg");

=head1 DESCRIPTION

Video::FrameGrab grabs a frame at the specified point in time from the 
specified video file and returns its JPEG data.

It uses mplayer for the heavy lifting behind the scenes and therefore 
requires it to be installed somewhere in the PATH.

=head1 LEGALESE

Copyright 2009 by Mike Schilli, all rights reserved.
This program is free software, you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 AUTHOR

2009, Mike Schilli <cpan@perlmeister.com>
