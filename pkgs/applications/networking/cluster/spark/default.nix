{ stdenv, fetchzip, makeWrapper, jre, pythonPackages
, mesosSupport ? true, mesos
, version
}:

let
  versionMap = {
    "1.6.0" = {
                hadoopVersion = "cdh4";
                sparkSha256 = "19ycx1r8g82vkvzmn9wxkssmv2damrg72yfmrgzpc6xyh071g91c";
              };
    "2.1.0" = {
                hadoopVersion = "hadoop2.4";
                sparkSha256 = "0pbsmbjwijsfgbnm56kgwnmnlqkz3w010ma0d7vzlkdklj40vqn2";
              };
  };
in

with versionMap.${version};

with stdenv.lib;

stdenv.mkDerivation rec {

  name = "spark-${version}";

  src = fetchzip {
    url    = "mirror://apache/spark/${name}/${name}-bin-${hadoopVersion}.tgz";
    sha256 = sparkSha256;
  };

  buildInputs = [ makeWrapper jre pythonPackages.python pythonPackages.numpy ]
    ++ optional mesosSupport mesos;

  untarDir = "${name}-bin-${hadoopVersion}";
  installPhase = ''
    mkdir -p $out/{lib/${untarDir}/conf,bin,/share/java}
    mv * $out/lib/${untarDir}

    sed -e 's/INFO, console/WARN, console/' < \
       $out/lib/${untarDir}/conf/log4j.properties.template > \
       $out/lib/${untarDir}/conf/log4j.properties

    cat > $out/lib/${untarDir}/conf/spark-env.sh <<- EOF
    export JAVA_HOME="${jre}"
    export SPARK_HOME="$out/lib/${untarDir}"
    export PYSPARK_PYTHON="${pythonPackages.python}/bin/${pythonPackages.python.executable}"
    export PYTHONPATH="\$PYTHONPATH:$PYTHONPATH"
    ${optionalString mesosSupport
      ''export MESOS_NATIVE_LIBRARY="$MESOS_NATIVE_LIBRARY"''}
    EOF

    for n in $(find $out/lib/${untarDir}/bin -type f ! -name "*.*"); do
      makeWrapper "$n" "$out/bin/$(basename $n)"
    done
    ln -s $out/lib/${untarDir}/lib/spark-assembly-*.jar $out/share/java
  '';

  meta = {
    description      = "Lightning-fast cluster computing";
    homepage         = "http://spark.apache.org";
    license          = stdenv.lib.licenses.asl20;
    platforms        = stdenv.lib.platforms.all;
    maintainers      = with maintainers; [ thoughtpolice offline ];
    repositories.git = git://git.apache.org/spark.git;
  };
}
