#!/bin/bash

# skan.sh
#
# This script is used to scan either documents or photos, then
# auto-crop the image (remove scanner bed from scanned image).
# It uses scanimage (sane) to scan the image. This scanned image
# is then automatically located on the scanner bed and cropped
# to the correct size using convert (imagemagick).
# 
# Default settings allow user to run the script with a single
# argument (output filename). However, there are several optional
# command line flags that provide more fine grained control
# over the scan and crop settings (see Usage section)
#
# TO DO:
#	1. allow user to crop existing image without scanning
#	2. add loop so user can scan several images in one session
#	3. change 'show' option to:
#			--show <val> (-s <val>):	opens cropped image with <val>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Usage: skan.sh <filename> <opt1> <opt2> <opt3> <opt4> <opt5> <opt6>
#
# Options:
#
#	Document Type:
#		--document	(-d):	color = b&w, dpi = 150, tone = light
#		--photo	(-p):	color = color
#
#		example:	skan.sh file -p
#
#	== Remaining options take effect with 'photo' document type ==
#
#	Image Tone:
#		--light	(-lt):	tone = light
#		--dark	(-dk):	tone = dark
#
#		example:	skan.sh file -dk
#
#	Resolution:
#		--resolution <val>	(-r <val>):	dpi = <val>
#
#			val choices:	150, 300
#
#		example:	skan.sh file -r 300
#
#	Show Result:
#		--show (-s):	opens cropped image with photoqt
#
#		example:	skan.sh file -s
#
#	Show Settings:
#		--verbose (-v):	prints values used for scan & crop
#
#		example:	skan.sh file -s
#
#	Manual Crop:
#		--manual (-m): scans image then opens in Gimp for manual cropping
#
#		example:	skan.sh file -m
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


# scanning function
skan(){
	scan_file=
	temp_file="$1"_temp.png
	img_type="$2"
	resolution="$3"
	scan_mode=
	shave_val=

	printf "\nOne moment please...\n\n"

	# set values for image type
	case "$2" in
		document)
			scan_file="$1".pnm
			scan_mode=gray
			;;
		photo)
			scan_file="$1".ppm
			scan_mode=color
			;;
	esac

	# set values for scan resolution
	case "$resolution" in
		300)
			shave_val='30x30'
			;;
		150)
			shave_val='15x15'
			;;
	esac

	# scan image
	scanimage  --mode "$scan_mode" --resolution "$resolution" > "$scan_file"

	# trim off scanner bed edge pixels
	convert "$scan_file" -shave "$shave_val" "$temp_file"

	rm "$scan_file"
}

# auto-cropping function
krop(){
	temp_file="$1"_temp.png
	done_file="$1".png
	img_type="$2"
	img_tone="$3"
	fx_escapes=
	fuzz_val=

	# set values for image type
	case "$img_type" in
		document)
			fx_escapes='%[fx:w+20]x%[fx:h+20]+%[fx:page.x-10]+%[fx:page.y-10]'
			fuzz_val='10%'
			;;
		photo)
			fx_escapes='%[fx:w]x%[fx:h]+%[fx:page.x]+%[fx:page.y]'

			# set values for image img_tone
			case "$img_tone" in
				dark)
					fuzz_val='60%'
					;;
				light)
					fuzz_val='50%'
					;;
			esac
			;;
	esac

	# find crop coordinates on scanner bed
	coords=$(convert "$temp_file" \
				-virtual-pixel edge \
				-blur 0x12 \
				-fuzz "$fuzz_val" \
				-trim -format \
					"$fx_escapes" \
				info:)

	# auto-crop image
	convert "$temp_file" -crop "$coords" +repage "$done_file"

	rm "$temp_file"
}


# user included no arguments (filename is required)
if [ "$#" -lt 1 ]
then
	printf "\nMissing Filename\n\n"
	printf "\nUsage: %s <filename> <opt1> <opt2> <opt3> <opt4> <opt5> <opt6>\n\n" "$0"
	exit 1
fi

# user included too many arguments
if [ "$#" -gt 7 ]
then
	printf "\nToo many arguments\n\n"
	printf "\nUsage: %s <filename> <opt1> <opt2> <opt3> <opt4> <opt5> <opt6>\n\n" "$0"
	exit 1
fi

# user placed <opt> argument before <filename> (filename should be first arg)
if [[ "${1:0:1}" = - ]]
then
	printf "\nInvalid Filename: %s \n\n" "$1"
	printf "(leading '%c' is used for <opt> flags\n\n" "${1:0:1}"
	exit 1
fi

# Default values
SCANSDIR=~/scans
FILENAME="$SCANSDIR"/"$1"
SCANTYPE=document
BRIGHTNESS=light
DPI=150
SHOW=false
MAN_CROP=false

# parse/store positional args
while [ "$2" != "" ]
do
	case "$2" in
		-d|--document)
			SCANTYPE=document
			DPI=150
			shift; shift; shift; shift; shift; shift
			;;
		-p|--photo)
			SCANTYPE=photo
			;;
		-lt|--light)
			BRIGHTNESS=light
			;;
		-dk|--dark)
			BRIGHTNESS=dark
			;;
		-r|--resolution)
			shift
			case "$2" in
				150|300)
					DPI="$2"
					;;
				*)
					printf "\n%d is not a valid resolution. Defaulting to 150\n\n" "$2"
					DPI=150
					;;
			esac
			;;
		-s|--show)
			SHOW=true
			;;
		-v|--verbose)
			printf "  Filename:  %s\n" "$FILENAME"
			printf " Scan Type:  %s\n" "$SCANTYPE"
			printf "Image Tone:  %s\n" "$BRIGHTNESS"
			printf "Resolution:  %s dpi\n" "$DPI"
			;;
		-m|--manual)
			MAN_CROP=true
			SHOW=false
			;;
		*)
			printf "\nInvalid Argument\n\n"
			printf "\nUsage: %s <filename> <opt1> <opt2> <opt3> <opt4> <opt5> <opt6>\n\n" "$0"
			printf "\nOptions:\n"
			printf "\t-d  | --document\n"
			printf "\t-p  | --photo\n"
			printf "\t-lt | --light\n"
			printf "\t-dk | --dark\n"
			printf "\t-r  | --resolution <dpi>> (150 OR 300)\n"
			printf "\t-s  | --show\n"
			printf "\t-v  | --verbose\n"
			printf "\t-m  | --manual\n\n"
			exit 1
			;;
	esac
	shift
done

# call scanner & auto-crop functions
skan "$FILENAME" "$SCANTYPE" "$DPI"
if [ "$MAN_CROP" = false ]
then
	krop "$FILENAME" "$SCANTYPE" "$BRIGHTNESS"
else
	gimp "$FILENAME"_temp.png &
fi

if [ "$SHOW" = true ]
then
	photoqt "$FILENAME".png &
fi
