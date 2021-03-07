#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';
use File::Find;
use File::Spec;
use File::Basename;
use File::Path qw/make_path/;
use Getopt::Long;
use MIME::Base64 qw(encode_base64);

# CONFIGURATION
# use constant PANDOC => 'C:\Users\denis.beurive\AppData\Local\Pandoc\pandoc.exe';
# use constant PANDOC => 'C:\Users\denis\AppData\Local\Pandoc\pandoc.exe';
use constant PANDOC => '/usr/bin/pandoc';


use constant CSS => 'pandoc.css';

use constant KEY_BASENAME => 'basename';
use constant KEY_ABSOLUTE_PATH => 'absolute path';
use constant KEY_ABSOLUTE_DIR => 'absolute dir';

my $__DIR__ = File::Spec->rel2abs(dirname(__FILE__));
my $PANDOC_CSS = File::Spec->catfile($__DIR__, CSS);
my $cli_root_path = $__DIR__;
my $cli_target_path = $__DIR__;
my $cli_verbose = 0;
my $cli_help = 0;

my $HELP = <<'HELP';
perl md2html.pl [--root-path=<root path>] \
                [--target-path=<target path>] \
                [--verbose] \
                [--help]
HELP

# Calculate the path to a destination file, given the following data:
# - The absolute path of the input file.
# - The absolute path of the directory that contains all the input files.
# - The absolute path to the output directory.
# @param $in_input_path The absolute path of the input file.
# @param The absolute path of the directory that contains all the input files.
# @param $in_output_root The absolute path to the output directory.
# @return The function returns a reference that contains 2 keys:
#         &KEY_ABSOLUTE_DIR: the absolute path to the directory that contains the output file.
#         &KEY_ABSOLUTE_PATH: the absolute path to the output file.

sub get_target_path {
    my ($in_input_path, $in_input_root, $in_output_root) = @_;
    my $input_relpath = File::Spec->abs2rel($in_input_path, $in_input_root);
    my $input_reldir = dirname($input_relpath);
    my $output_absdir = File::Spec->catfile($in_output_root, $input_reldir);
    my $output_abspath = File::Spec->catfile($output_absdir, basename($in_input_path));
    return { &KEY_ABSOLUTE_DIR => $output_absdir, &KEY_ABSOLUTE_PATH => $output_abspath }
}

# Convert a given image into its base64 representation.
# @param $in_path Path to the image to convert.
# @return The function returns the base64 representation of the image.

sub image2base64 {
    my ($in_path) = @_;

    my @data = stat($in_path);
    if (0 == scalar(@data)) { die(sprintf('Cannot stat file "%s": %s', $in_path, $!)); }
    my $file_size = $data[7];

    my $bytes;
    open(my $fd, '<', $in_path)
        or die(sprintf('Cannot open file "%s": %s', $in_path, $!));
    binmode($fd);
    read($fd, $bytes, $file_size);
    close($fd);
    my $b64 = encode_base64($bytes, '');
    return $b64;
}

# Embed all images from a given HTML file.
# @param $in_html_doc_path Absolute path to the HTML file.
# @param $in_root_dir_path Absolute path to the directory that contains (all) the MD files to convert.
# @return The function returns the HTML code that contains the embedded images.

sub embedHtml {
    my ($in_html_doc_path, $in_root_dir_path) = @_;

    open(my $fd, '<', $in_html_doc_path)
        or die(sprintf('Cannot open file "%s" (%s): %s', $in_html_doc_path, $in_root_dir_path, $!));
    my @lines = <$fd>;
    close($fd);

    foreach my $line (@lines) {
        if ($line =~ m/<img src="([^"]+)"/) {
            my $local_image_path = $1;
            my $extension_pos = rindex($local_image_path, ".");

            (-1 != $extension_pos) or die(sprintf('Invalid image file name "%s" (no extension)', $local_image_path));
            my $extension = substr($local_image_path, $extension_pos+1);
            # Example:
            #   $in_html_doc_path: C:\Users\denis\CLionProjects\openssl\doc\clion.html
            #   $in_root_dir_path: C:\Users\denis\CLionProjects\openssl
            #   $rel_dir:          doc
            my $rel_dir = dirname(File::Spec->abs2rel($in_html_doc_path, $in_root_dir_path));
            my $image = File::Spec->catfile($in_root_dir_path, $rel_dir, $local_image_path);

            printf("  Convert \"%s\" (%s) into base64\n", $local_image_path, $image) if ($cli_verbose);
            my $text = "data:image/${extension};base64," . image2base64($image);
            $line =~ s/<img src="([^"]+)"/<img src="${text}"/;
        }
    }
    return join('', @lines);
}

# Given an HTML file that contains links to MD files, this function replaces the targets of the links,
# so that the links point to HTML files instead. For example, the link <a href="link.md"> is replaced
# by the link <a href="link.html">.
# @param $in_input_path Path to the HTML file to process.

sub convert_md_links {
    my ($in_input_path) = @_;
    open(my $fd, '<', $in_input_path)
        or die(sprintf('Cannot open file "%s": %s', $in_input_path, $!));
    my @lines = <$fd>;
    close($fd);
    my $html = join('', @lines);
    $html =~ s/<a href="([^"]+)\.md">/<a href="$1.html">/igm;
    open($fd, '>', $in_input_path)
        or die(sprintf('Cannot open file "%s": %s', $in_input_path, $!));
    print $fd $html;
    close($fd)
}

# Sanity checks.

if (! -e &PANDOC) {
    printf("ERROR: the pandoc executable \"%s\" cannot be found! Please configure the constant \"PANDOC\".\n", &PANDOC);
    exit(1);
}

# -----------------------------------------------------------------------
# Parse the command line.
# -----------------------------------------------------------------------

unless (
    GetOptions (
        'help'                               => \$cli_help,
        'verbose'                            => \$cli_verbose,
        'root-path=s'                        => \$cli_root_path,
        'target-path=s'                      => \$cli_target_path,
    )
) { die "ERROR: Invalid command line.\n" }

if ($cli_help) {
    print "${HELP}\n";
    exit(0)
}

$cli_root_path = File::Spec->rel2abs($cli_root_path);
$cli_target_path = File::Spec->rel2abs($cli_target_path);

if ($cli_verbose) {
    printf("Root path:   \"%s\"\n", $cli_root_path);
    printf("Target path: \"%s\"\n\n", $cli_target_path);
}

# -----------------------------------------------------------------------
# List all MarkDown files to convert.
# -----------------------------------------------------------------------

my @md_files = ();
sub wanted {
    push(@md_files, {
        &KEY_BASENAME => $_,
        &KEY_ABSOLUTE_PATH => File::Spec->rel2abs($File::Find::name)
    }) if ($_ =~ m/\.md$/i);
}
find(\&wanted, ($cli_root_path));

if ($cli_verbose) {
    print("MarkDown files to convert:\n");
    foreach my $file (@md_files) { printf("- \"%s\"\n", $file->{&KEY_ABSOLUTE_PATH}) }
    print("\n");
}

# -----------------------------------------------------------------------
# Convert all MarkDown files into HTML files (using Pandoc).
# -----------------------------------------------------------------------

print("Convert MD to HTML:\n") if ($cli_verbose);
my @html_files = ();
foreach my $file (@md_files) {
    my $md_file = $file->{&KEY_ABSOLUTE_PATH};
    my $target = get_target_path($md_file, $cli_root_path, $cli_target_path);
    my $target_dir = $target->{&KEY_ABSOLUTE_DIR};
    my $target_file = $target->{&KEY_ABSOLUTE_PATH};
    $target_file =~ s/\.md$/.html/i;
    push(@html_files, $target_file);

    make_path($target_dir) unless(-d $target_dir);
    unlink($target_file) if (-e $target_file);
    printf("- ${md_file} -> ${target_file}\n") if ($cli_verbose);
    my @cmd = (
        &PANDOC,
        $md_file,
        '-f',
        'markdown',
        '-t',
        'html',
#        '--quiet',
        '--include-in-header',
        $PANDOC_CSS,
        '-s',
        '-o',
        $target_file
    );
    printf("Exec: %s\n", join(' ', @cmd)) if ($cli_verbose);

    system(@cmd);

    convert_md_links($target_file)
}
print("\n") if ($cli_verbose);

# -----------------------------------------------------------------------
# Replace images by base64 embedded images in all HTML files.
# -----------------------------------------------------------------------

print("Embed images in HTML files:\n") if ($cli_verbose);
foreach my $file (@html_files) {
    if ($cli_verbose) {
        printf("- %s\n", $file);
    }
    my $html = embedHtml($file, $cli_root_path);
    open(my $fd, '>', $file)
        or die(sprintf('Cannot open file "%s": %s', $file, $!));
    print $fd $html;
    close($fd);
}

