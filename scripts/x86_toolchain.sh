#! /bin/bash

# Created by Lubos Kuzma
# ISS Program, SADT, SAIT
# November 2023


if [ $# -lt 1 ]; then
	echo "Usage:"
	echo ""
	echo "x86_toolchain.sh [ options ] <assembly filename> [-o | --output <output filename>]"
	echo ""
	echo "Autodetect .cpp file extension for G++ compiler"
	echo ""
	echo "-v | --verbose                Show some information about steps performed."
	echo "-g | --gdb                    Run gdb command on executable."
	echo "-b | --break <break point>    Add breakpoint after running gdb. Default is _start."
	echo "-r | --run                    Run program in gdb automatically. Same as run command inside gdb env."
	echo "-q | --qemu                   Run executable in QEMU emulator. This will execute the program."
	echo "-64| --x86-64                 Compile for 64bit (x86-64) system."
	echo "-o | --output <filename>      Output filename."
	echo "-G | --gcc                    Use GCC compiler" # this option enables gcc compiler
	echo "-S | --assembly-code          Output assembly (.s) file" #this option enables output of assembly code from a C file
    echo "-C | --machine-code           Output object(.o) file"      #this option will allow the user to get object code from a C file
	echo ""

	exit 1
fi

POSITIONAL_ARGS=()
GDB=False
OUTPUT_FILE=""
VERBOSE=False
BITS=False
QEMU=False
BREAK="_start"
RUN=False
GCC=False # add gcc in positional_args
ASM=FALSE 
OBJ=FALSE
while [[ $# -gt 0 ]]; do
	case $1 in
		-g|--gdb)
			GDB=True
			shift # past argument
			;;
		-o|--output)
			OUTPUT_FILE="$2"
			shift # past argument
			shift # past value
			;;
		-v|--verbose)
			VERBOSE=True
			shift # past argument
			;;
		-64|--x84-64)
			BITS=True
			shift # past argument
			;;
		-q|--qemu)
			QEMU=True
			shift # past argument
			;;
		-r|--run)
			RUN=True
			shift # past argument
			;;
		-b|--break)
			BREAK="$2"
			shift # past argument
			shift # past value
			;;
		-G|--gcc) # add gcc argument
            GCC=True
            shift # past argument
            ;;
		-S|--assembly-code)
            ASM=True
            shift #past argument
            ;;
		-C|--machine-code)
            OBJ=True
            shift #past argument
            ;;
		-*|--*)
			echo "Unknown option $1"
			exit 1
			;;
		*)
			POSITIONAL_ARGS+=("$1") # save positional arg
			shift # past argument
			;;
	esac
done

set -- "${POSITIONAL_ARGS[@]}" # restore positional parameters

if [[ ! -f $1 ]]; then
	echo "Specified file does not exist"
	exit 1
fi

if [ "$OUTPUT_FILE" == "" ]; then
	OUTPUT_FILE=${1%.*}
fi

if [ "$VERBOSE" == "True" ]; then
	echo "Arguments being set:"
	echo "	GDB = ${GDB}"
	echo "	RUN = ${RUN}"
	echo "	BREAK = ${BREAK}"
	echo "	QEMU = ${QEMU}"
	echo "	Input File = $1"
	echo "	Output File = $OUTPUT_FILE"
	echo "	Verbose = $VERBOSE"
	echo "	64 bit mode = $BITS" 
	echo "  GCC compiler = ${GCC}" # add the gcc arguments into verbose output
	echo "	Ouput assembly (.s) file"
	echo "	Output object (.o) file"
	echo ""

	echo "NASM started..."

fi

#Propose adding simple G++ compiler as well:
#start
if [[ $1 == *.cpp ]]; then

	g++ -o $OUTPUT_FILE.cpp && echo "" # if input file ends with .cpp it will use g++
									   # to create the executable, if not it will follow the existing logic for NASM
#end
else

if [ "$BITS" == "True" ]; then

	nasm -f elf64 $1 -o $OUTPUT_FILE.o && echo ""


elif [ "$BITS" == "False" ]; then

	nasm -f elf $1 -o $OUTPUT_FILE.o && echo ""

fi

if [ "$VERBOSE" == "True" ]; then

	echo "NASM finished"
	echo "Linking ..."
	
fi

if [ "$VERBOSE" == "True" ]; then

	echo "NASM finished"
	echo "Linking ..."
fi

if [ "$BITS" == "True" ]; then

	ld -m elf_x86_64 $OUTPUT_FILE.o -o $OUTPUT_FILE && echo ""


elif [ "$BITS" == "False" ]; then

	ld -m elf_i386 $OUTPUT_FILE.o -o $OUTPUT_FILE && echo ""

fi


if [ "$VERBOSE" == "True" ]; then

	echo "Linking finished"

fi

if [ "$QEMU" == "True" ]; then

	echo "Starting QEMU ..."
	echo ""

	if [ "$BITS" == "True" ]; then
	
		qemu-x86_64 $OUTPUT_FILE && echo ""

	elif [ "$BITS" == "False" ]; then

		qemu-i386 $OUTPUT_FILE && echo ""

	fi

	exit 0
	
fi

if [ "$GDB" == "True" ]; then

	gdb_params=()
	gdb_params+=(-ex "b ${BREAK}")

	if [ "$RUN" == "True" ]; then

		gdb_params+=(-ex "r")

	fi

	gdb "${gdb_params[@]}" $OUTPUT_FILE

fi

if [ "$GCC" == "True" ]; then # add gcc [inputfile] -o [outputfile]

	echo "starting GCC..."
	echo "For 32-bit compilation first install gcc-multilib:"   # tell user how to compile 32-bit programs
	echo "sudo apt-get install gcc-multilib"
	echo "Visit: https://www.geeksforgeeks.org/compile-32-bit-program-64-bit-gcc-c-c/ for more information."
	echo ""

	if [ "$VERBOSE" == "True" ]; then # add option for verbose gcc output

		gcc -v $OUTPUT_FILE.c -o $OUTPUT_FILE && echo ""
        
	elif [ "$BITS" == "True" ]; then # add option for x64 compilation

		gcc -m64 $OUTPUT_FILE.c -o $OUTPUT_FILE && echo ""
        
    elif [ "$BITS" == "False" ]; then # add option for x32 compilation

    	gcc -m32 $OUTPUT_FILE.c -o $OUTPUT_FILE && echo ""

fi
	
if [ "$ASM" == "True" ]; then  #Compile to assembly

    if [ "$GCC" == "False" ]; then

		echo "WARNING: The -S|--assembly code option requires the -G|--gcc option to use. Aborting..."
        exit 1 # Abort the scropt if -G was not switched on
	else
		gcc -S $OUTPUT_FILE.c -masm=intel -o $OUTPUT_FILE && echo ""

	fi
fi

if [ "$OBJ" == "True" ]; then #compile to object file

	if [ "$GCC" == "False" ]; then
		
        echo "WARNING: The -C|--machine-code option requires the -G|--gcc option to use. Aborting..."
        exit 1 #Abort the script if -G was not switched on
	
	else
		gcc -c $OUTPUT_FILE.c -o $OUTPUT_FILE && echo ""
	
	fi
fi

