#!/bin/sh

echo running program
/usr/bin/dotnet exec LambdaOrFargate.dll pause &
pid=$!
