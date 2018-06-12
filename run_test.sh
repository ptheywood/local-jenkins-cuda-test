#! /bin/bash

./bin/release/test 

retcode=$?
if [ $retcode -ne 0 ]; then
    echo "Error"
fi
echo $retcode
exit $retcode
