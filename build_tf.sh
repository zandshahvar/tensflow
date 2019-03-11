# Check whether script is executing in a VirtualEnv or Conda environment
if [ -z "$VIRTUAL_ENV" ] && [ -z "$CONDA_PREFIX" ] ; then
	echo "VirtualEnv or Conda env is not activated"
	exit -1
fi

# Set the virtual environment path
if ! [ -z "$VIRTUAL_ENV" ] ; then
  VENV_PATH=$VIRTUAL_ENV
elif ! [ -z "$CONDA_PREFIX" ] ; then
  VENV_PATH=$CONDA_PREFIX
fi

# Set the bin and lib directories
VENV_BIN=$VENV_PATH/bin
VENV_LIB=$VENV_PATH/lib

# bazel tf needs these env vars
export PYTHON_BIN_PATH=$VENV_BIN/python
export PYTHON_LIB_PATH=`ls -d $VENV_LIB/*/ | grep python`

# Set the native architecture optimization flag, which is a default
COPT="--copt=-march=native"

# Determine the available features of your CPU
raw_cpu_flags=`sysctl -a | grep machdep.cpu.features | cut -d ":" -f 2 | tr '[:upper:]' '[:lower:]'`

# Append each of your CPU's features to the list of optimization flags
for cpu_feature in $raw_cpu_flags
do
	case "$cpu_feature" in
		"sse4.1" | "sse4.2" | "ssse3" | "fma" | "cx16" | "popcnt" | "maes")
		    COPT+=" --copt=-m$cpu_feature"
		;;
		"avx1.0")
		    COPT+=" --copt=-mavx"
		;;
		*)
			# noop
		;;
	esac
done

# First ensure a clear working directory in case you've run bazel previously
bazel shutdown

# Run TensorFlow configuration (accept defaults unless you have a need)
./configure

# Build the TensorFlow pip package
bazel build -c opt $COPT -k //tensorflow/tools/pip_package:build_pip_package
bazel-bin/tensorflow/tools/pip_package/build_pip_package /tmp/tensorflow_pkg
