#!/bin/bash 
reference="kafka_2.11-1.0.0"
localdir=`pwd`
baseDir=`basename $localdir`
sinkConfig="libs/kafka-connect-couchbase-3.2.1/config/quickstart-couchbase-sink.properties"
sourceConfig="libs/kafka-connect-couchbase-3.2.1/config/quickstart-couchbase-source.properties"
backFill=0
loadgenCmd="docker exec -it CB-551 /bin/bash -c "/opt/couchbase/bin/cbc-pillowfight -B 10 -I 1000 -p ProfileDoc:: -t 1 -R -J -m 50 -M100 --rate-limit 100 -P password -u Administrator -U couchbase://localhost/regional""

executeLoad() {
printf "Do you want to execute data load? (y/n) "
while read choice 
	do 
case $choice in
      y|Y) echo "executing load generation" 
	   docker exec -it CB-551 /bin/bash -c "/opt/couchbase/bin/cbc-pillowfight -B 10 -I 1000 -p ProfileDoc:: -t 1 -R -J -m 50 -M101 --rate-limit 100 -P password -u Administrator -U couchbase://localhost/regional"
	;;
      n|N) echo "no load generation active. Please execute the following command:" 
	   echo $loadgenCmd
	;;
       *) echo "Invalid option. Skipping load generation"
	;;
esac
done
}

validateFiles () { 
echo "Verifying configuration properties files exist"
echo "Checking $sinkConfig"
fileCheck $sinkConfig
echo "Checking $sourceConfig"
fileCheck $sourceConfig
}

checkBackfill()  {
while read $1
 do printf "Do you want to use the backfill config file? (y/n) "
case $1 in 
    y|Y) echo "Starting backfill queue"
        backfill=1
	;;
    n|N) echo "starting standard queue"
        backfill=0
	;;
     *) echo "Incorrect option, please enter one of y or n"
        checkBackfill
	;;
esac
done

if [ $backfill -eq 1 ] 
then sinkConfig="libs/kafka-connect-couchbase-3.2.1/config/quickstart-couchbase-source-backfill.properties"
fi
}


fileCheck () {
File=$1
if [ -r $File ]
then echo " $File is good!" 
     return 0
else echo "Error! Cannot read $File!"
     return 1
fi
}

counter() {
if [ $1 -lt 1 ] || [ ! $1 ]
then count=1
else count=$1
fi

while [ $count -gt 0 ] 
do printf '.'
   sleep 1 
   count=$[$count - 1] 
done
}


Main() {
#do you want to start the queues from first document forward
#checkBackfill

#check files for validity and pathing
validateFiles
if [ $? -eq 0 ]
then 
     echo "Properties files check passed. Starting Kafka"
else 
     echo "Problem with properties files check. Please fix issues and try again"
     exit 1
fi

if [ $baseDir == $reference ] || [ $baseDir != bin ] 
then 
     echo "Attempting to start zookeeper in the background ..."
     bin/zookeeper-server-start.sh config/zookeeper.properties &
	counter 10 
#
     echo "Attempting to start kafka-server in the background ..."
     bin/kafka-server-start.sh config/server.properties &
	counter 10 
 
#
     echo "Exporting classpath for kafka-connect-couchbase-3.2.1.jar and custom-source-handler-1.0-SNAPSHOT.jar ..."
     export CLASSPATH=/Users/austin/Downloads/kafka_2.11-1.0.0/libs/kafka-connect-couchbase-3.2.1/kafka-connect-couchbase-3.2.1.jar:/Users/austin/Downloads/kafka_2.11-1.0.0/libs/kafka-connect-couchbase-3.2.1/custom-source-handler-1.0-SNAPSHOT.jar

     echo "Starting standalone kafka connect couchbase client ..." 
     ./bin/connect-standalone.sh config/connect-standalone.properties libs/kafka-connect-couchbase-3.2.1/config/quickstart-couchbase-sink.properties libs/kafka-connect-couchbase-3.2.1/config/quickstart-couchbase-source.properties &> $PWD/logs/run-demo.$$.log&

counter 10
executeLoad y 

else
   echo "This is not the proper directory to run the Kafka demo"
   echo "Please change directories to $reference and try again"
   exit 1
fi
}

Main
