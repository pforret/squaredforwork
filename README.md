# squaredforwork

**create reveal movies for pictures with imagemagick, ffmpeg and primitive**

## Usage

    Program: sfw_movie.sh 1.2.1 by peter@forret.com
    Updated: Jan 21 12:53:06 2021
    Usage: sfw_movie.sh [-h] [-q] [-v] [-f] [-1 <instagram>] [-2 <tiktok>] [-3 <facebook>] [-b <border>] [-c <credits>] [-e <extension>] [-l <log_dir>] [-m <method>] [-o <opening>] [-p <steps>] [-r <resize>] [-t <tmp_dir>] [-i <img_dir>] [-j <out_dir>] <action> <input …> <output …>
    Flags, options and parameters:
    -h|--help      : [flag] show usage [default: off]
    -q|--quiet     : [flag] no output [default: off]
    -v|--verbose   : [flag] output more [default: off]
    -f|--force     : [flag] do not ask for confirmation (always yes) [default: off]
    -1|--instagram <?>: [optn] export folder for instagram
    -2|--tiktok <?>   : [optn] export folder for tiktok
    -3|--facebook <?> : [optn] export folder for facebook
    -b|--border <?>   : [optn] add border to original image  [default: 0]
    -c|--credits <?>  : [optn] credits to add at the end  [default: < Concept: @squaredforwork >]
    -e|--extension <?>: [optn] output extension  [default: m4v]
    -l|--log_dir <?>  : [optn] folder for log files   [default: log]
    -m|--method <?>   : [optn] primitive method  [default: 7]
    -o|--opening <?>  : [optn] opening text  [default: Guess the movie?]
    -p|--steps <?>    : [optn] steps done by primitive  [default: 600]
    -r|--resize <?>   : [optn] resize WxH  [default: 120x180]
    -t|--tmp_dir <?>  : [optn] folder for temp files  [default: .tmp]
    -i|--img_dir <?>  : [optn] folder for poster images  [default: image]
    -j|--out_dir <?>  : [optn] folder for output movies  [default: output]
    <action>  : [parameter] action to perform: image/imdb
    <input>   : [parameters] input image/film name (1 or more)
    <output>  : [parameters] output file or '-' for automatic filename (1 or more)  

## Examples

These are some low-res GIF versions of the end result:

Full size (800x1200):

![Example 1](assets/trumanshow.gif)

Half size (400x600): 

![Example 2](assets/thehelp.gif)

And an actual video can be viewed here: [The Help (5MB .m4v)](assets/thehelp.m4v)
