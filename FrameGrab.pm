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

our $VERSION = "0.04";

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
            "-ao", "null",
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
sub cropdetect {
###########################################
    my($self, $time) = @_;

    if(!defined $time) {
        LOGDIE "Missing parameter: time";
    }

    my($stdout, $stderr, $rc) = 
        tap $self->{mplayer}, qw(-vf cropdetect -ss), $time, 
            "-frames", 10,
            "-vo", "null",
            "-ao", "null",
            $self->{video};

    if(defined $stdout and
       $stdout =~ /-vf crop=(\d+):(\d+):(\d+):(\d+)/) {
        DEBUG "Suggested crop: $1, $2, $3, $4";
        return ($1, $2, $3, $4);
    }

    ERROR "$stderr";

    return undef;
}

###########################################
sub cropdetect_average {
###########################################
    my($self, $nof_probes, $movie_length) = @_;

    $self->result_clear();

    for my $probe ( 
          $self->equidistant_snap_times( $nof_probes, $movie_length ) ) {
        my @params = $self->cropdetect( $probe );
        if(! defined $params[0] ) {
            ERROR "cropdetect returned an error";
            next;
        }
        DEBUG "Cropdetect at $probe yielded (@params)";
        $self->result_push( @params );
    }

    my @result = $self->result_majority_decision();
    DEBUG "Majority decision: (@result)";
    return @result;
}

###########################################
sub result_clear  {
###########################################
    my($self) = @_;

    $self->{result} = [];
}

###########################################
sub result_push {
###########################################
    my($self, @result) = @_;

    for(0..$#result) {
        $self->{result}->[$_]->{ $result[$_] }++;
    }
}

###########################################
sub result_majority_decision {
###########################################
    my($self) = @_;

    my @result = ();

    for my $sample (@{ $self->{result} }) {
        my($majority) = sort { $sample->{$b} <=> $sample->{$a} } keys %$sample;
        push @result, $majority;
    }

    return @result;
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
    my($self, $nof_snaps, $movie_length) = @_;

    if(! defined $nof_snaps) {
        LOGDIE "Parameter missing: nof_snaps";
    }

    my @stamps = ();

    if(!defined $self->{meta}) {
        $self->meta_data();
    }

    my $length = $self->{meta}->{length};
    $length = $movie_length if defined $movie_length;

    my $interval = $length / ($nof_snaps + 1.0);
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

=item equidistant_snap_times( $howmany, [$movie_length] )

If you want to snap N frames at constant intervals throughout the movie,
use equidistant_snap_times( $n ) to get a list of timestamps you can use
later pass to snap(). For example, on a two hour movie, 
equidistant_snap_times( 5 ) will return

    00:20:00
    00:40:00
    01:00:00
    01:20:00
    01:40:00

as a list of strings. The movie length is determined by a call to meta
data, but some formats don't allow retrieving the movie length that way,
therefore the optional parameter $movie_length lets you specify the
length of the movie (or the length of the overall interval to perform
the snapshots in) in seconds.

=item cropdetect( $time )

Asks mplayer to come up with a recommendation on how to crop the video.
If this is a 16:9 movie converted to 4:3 format, the black bars at the bottom
and the top of the screen should be cropped out and C<cropdetect> will
return a list of ($width, $height, $x, $y) to be passed to mplayer/mencoder
in the form C<-vf crop=w:h:x:y> to accomplish the suggested cropping.

Note that this is just a guess and might be incorrect at times, but
if you repeat it at several times during the movie (e.g. by using
the equidistant_snap_times method described above), the result
is fairly accurate. C<cropdetect_average>, described below, does exactly 
that.

=item cropdetect_average( $number_of_probes, [$movie_length] )

Takes C<$number_of_probes> from the movie at equidistant intervals,
runs C<cropdetect> on them and returns a result computed by 
majority decision over all probes (ties are broken randomly).
See C<equidistant_snap_times> for the optional C<$movie_length> parameter.

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
