###########################################
package Video::FrameGrab;
###########################################

use strict;
use warnings;
use Sysadm::Install qw(bin_find tap slurp blurt);
use File::Temp qw(tempdir);
use DateTime;
use DateTime::Duration;
use DateTime::Format::Duration;

use Log::Log4perl qw(:easy);

our $VERSION = "0.03";

###########################################
sub new {
###########################################
    my($class, %options) = @_;

    my $self = {
        mplayer => undef,
        tmpdir  => tempdir(CLEANUP => 1),
        meta    => undef,
        video   => undef,
        %options,
    };

    if(! defined $self->{video}) {
        LOGDIE "Parameter missing: video";
    }

    if(! defined $self->{mplayer}) {
        $self->{mplayer} = bin_find("mplayer"),
    }

    if(!defined $self->{mplayer} or ! -x $self->{mplayer}) {
        LOGDIE "Fatal error: Can't find mplayer";
    }

    bless $self, $class;
}

###########################################
sub snap {
###########################################
    goto &frame_grab;
}

###########################################
sub frame_grab {
###########################################
    my($self, $time) = @_;

    my $tmpdir = $self->{tmpdir};

    for (<$tmpdir/*>) {
        unlink $_;
    }

    my($stdout, $stderr, $rc) = 
        tap $self->{mplayer}, qw(-frames 1 -ss), $time, 
            "-vo", "jpeg:maxfiles=1:outdir=$self->{tmpdir}",
            $self->{video};

    if($rc != 0) {
        ERROR "$stderr";
        return undef;
    }

    my $frame = "$self->{tmpdir}/00000001.jpg";

    if(! -f $frame) {
        ERROR "$stderr";
        return undef;
    }

    $self->{jpeg} = slurp("$self->{tmpdir}/00000001.jpg");
    return $self->{jpeg}
}

###########################################
sub jpeg_data {
###########################################
    my($self) = @_;
    return $self->{jpeg};
}

###########################################
sub jpeg_save {
###########################################
    my($self, $file) = @_;

    blurt $self->{jpeg}, $file;
}

###########################################
sub meta_data {
###########################################
    my($self) = @_;

    my($stdout, $stderr, $rc) = 
        tap $self->{mplayer}, 
            qw(-vo null -ao null -frames 0 -identify), 
            $self->{video};

    if($rc != 0) {
        ERROR "$stderr";
        return undef;
    }

    $self->{meta} = {};

    while($stdout =~ /^ID_(.*?)=(.*)/mg) {
        $self->{meta}->{ lc($1) } = $2;
    }

    return $self->{meta};
}

###########################################
sub equidistant_snap_times {
###########################################
    my($self, $nof_snaps) = @_;

    if(! defined $nof_snaps) {
        LOGDIE "Parameter missing: nof_snaps";
    }

    my @stamps = ();

    if(!defined $self->{meta}) {
        $self->meta_data();
    }

    my $interval = $self->{meta}->{length} / ($nof_snaps + 1.0);
    my $interval_seconds     = int( $interval );

    my $dur   = DateTime::Duration->new(seconds => $interval_seconds);
    my $point = DateTime::Duration->new(seconds => 0);

    my $format = DateTime::Format::Duration->new(pattern => "%r");
    $format->set_normalizing( "ISO" );

    for my $snap_no (1 .. $nof_snaps) {
        $point->add_duration( $dur );

        my $stamp = $format->format_duration( $point );
        push @stamps, $stamp;
    }

    return @stamps;
}

1;

__END__

=head1 NAME

Video::FrameGrab - Grab a frame or metadata from a video

=head1 SYNOPSIS

    use Video::FrameGrab;

    my $grabber = Video::FrameGrab->new( video => "movie.avi" );

    my $jpg_data = $grabber->snap( "00:00:10" );
    $grabber->jpeg_save("snapshot.jpg");

    print "This movie is ", 
          $grabber->meta_data()->{length}, 
          " seconds long\n";

      # Snap 10 frames at constant intervals throughout the movie
    for my $p ( $grabber->equidistant_snap_times(10) ) {
        $grabber->snap( $p );
        $grabber->jpeg_save("frame-at-$p.jpg");
    }

=head1 DESCRIPTION

Video::FrameGrab grabs a frame at the specified point in time from the 
specified video file and returns its JPEG data.

It uses mplayer for the heavy lifting behind the scenes and therefore 
requires it to be installed somewhere in the PATH. If mplayer is somewhere
else, its location can be provided to the constructor:

    my $grabber = Video::FrameGrab->new( mplayer => "/path/to/mplayer",
                                         video   => "movie.avi"
                                       );

=head2 METHODS

=over 4

=item snap( $time )

Grabs a frame from the movie at time $time. Time is given as HH::MM::SS,
just as mplayer likes it. Returns the raw jpeg data of the captured frame
on success and undef if an error occurs.

=item jpeg_save( $jpg_file_name )

Save a grabbed frame as a jpeg image in $file on disk.

=item meta_data()

Runs mplayer's identify() function and returns a reference to a hash
containing something like

    demuxer          => MOV
    video_format     => AVC1
    video_bitrate    => 0
    video_width      => 320
    video_height     => 240
    video_fps        => 29.970
    video_aspect     => 0.0000
    audio_format     => MP4A
    audio_bitrate    => 0
    audio_rate       => 48000
    audio_nch        => 2
    length           => 9515.94

=item equidistant_snap_times( $howmany )

If you want to snap N frames at constant intervals throughout the movie,
use equidistant_snap_times( $n ) to get a list of timestamps you can use
later pass to snap(). For example, on a two hour movie, 
equidistant_snap_times( 5 ) will return

    00:20:00
    00:40:00
    01:00:00
    01:20:00
    01:40:00

as a list of strings. 

=head1 CAVEATS

Note that the mplayer-based frame grabbing mechanism used in 
this module allows you to snap a picture about every 10 seconds into the 
movie, on shorter intervals, you'll get the same frame back.

=back

=head1 LEGALESE

Copyright 2009 by Mike Schilli, all rights reserved.
This program is free software, you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 AUTHOR

2009, Mike Schilli <cpan@perlmeister.com>
