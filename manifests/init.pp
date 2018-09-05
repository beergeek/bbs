# A description of what this class does
#
# @summary A short summary of the purpose of this class
#
# @example
#   include bbs
class bbs (
  Stdlib::Absolutepath    $java_home,
  Bbs::Db_type            $db_type               = 'postgresql',
  Bbs::Memory             $jvm_xms               = '512m',
  Bbs::Memory             $jvm_xmx               = '1024m',
  Bbs::Pathurl            $mysql_driver_source   = 'https://dev.mysql.com/get/Downloads/Connector-J',
  Bbs::Pathurl            $source_location       = 'https://downloads.atlassian.com/software/stash/downloads',
  Boolean                 $manage_db_settings    = false,
  Boolean                 $manage_grp            = true,
  Boolean                 $manage_user           = true,
  Optional[Stdlib::Fqdn]  $db_host               = 'localhost',
  Optional[String]        $db_name               = undef,
  Optional[String]        $db_password           = undef,
  Optional[String]        $db_port               = undef,
  Optional[String]        $db_user               = undef,
  Optional[String]        $java_args             = undef,
  # Version 8 causes issues with Bbs
  Optional[String]        $mysql_driver_pkg      = 'mysql-connector-java-5.1.46.tar.gz',
  # $mysql_driver_jar_name must come after $mysql_driver_pkg
  Optional[String]        $mysql_driver_jar_name = "${basename($mysql_driver_pkg, '.tar.gz')}.jar",
  Stdlib::Absolutepath    $bbs_data_dir          = '/var/atlassian/application-data/stash',
  Stdlib::Absolutepath    $bbs_install_dir       = '/opt/atlassian/stash',
  String                  $bbs_grp               = 'atlbitbucket',
  String                  $bbs_user              = 'atlbitbucket',
  String                  $version               = '5.13.1',
) {

  contain bbs::install
  contain bbs::config
  contain bbs::service

  Class['bbs::install'] -> Class['bbs::config'] -> Class['bbs::service']
}
