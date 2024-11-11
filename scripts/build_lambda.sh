set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"


BUILD_DIR="lambda_build"
DIST_DIR="dist"
PACKAGE_DIR="$DIST_DIR/package"


mkdir -p $BUILD_DIR
mkdir -p $DIST_DIR
mkdir -p $PACKAGE_DIR


python3 -m venv $BUILD_DIR/venv
source $BUILD_DIR/venv/bin/activate


pip install --upgrade pip
pip install -r $PROJECT_ROOT/requirements.txt \
    --platform manylinux2014_x86_64 \
    --target $PACKAGE_DIR \
    --implementation cp \
    --python-version 3.9 \
    --only-binary=:all:


cp $PROJECT_ROOT/src/lambda/process_file/main.py $PACKAGE_DIR/

rm -rf $BUILD_DIR

echo "Lambda build completed successfully"