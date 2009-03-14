######################################################################
# Test suite for FrameGrab
# by Mike Schilli <cpan@perlmeister.com>
######################################################################
use warnings;
use strict;

use Test::More;
use Sysadm::Install qw(slurp);
use File::Temp qw(tempfile);
use Log::Log4perl qw(:easy);
plan tests => 4;

my $canned = "canned";
$canned = "t/canned" unless -d $canned;
my $video = "$canned/plane.avi";

use Video::FrameGrab;

my($tmp_fh, $tmp_file) = tempfile(UNLINK => 1);

SKIP: {
    my $grabber;
    
    eval { $grabber = Video::FrameGrab->new(); };

    if($@ =~ /Can't find mplayer/) {
        skip "Mplayer not installed -- skipping all tests", 4;
    }

    my $rc = $grabber->frame_grab("hula.avi", "00:00:10");
    ok(!$rc, "frame from non-existent file");

    my($fh, $file) = tempfile(UNLINK => 1);
    $rc = $grabber->frame_grab($file, "00:00:10");
    ok(!$rc, "frame from empty file");

    # Test video
    my $meta = $grabber->meta_data( $video );
    is($meta->{"length"}, "1.00", "meta data length");
    is($meta->{video_bitrate}, "733360", "meta data bitrate");
};
