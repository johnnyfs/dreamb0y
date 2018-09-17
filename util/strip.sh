for FILE in $(ls *.out)
  do NAME=$(echo $FILE | sed -s 's/\.out//')
     mv $FILE $NAME
done
