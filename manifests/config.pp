class bbs::config {

  assert_private()

  File {
    owner   => $bbs::bbs_user,
    group   => $bbs::bbs_grp,
    mode    => '0644',
  }

  File_line {
    path    => "${bbs::bbs_data_dir}/bitbucket.cfg.xml",
  }

  if $facts['os']['name'] == 'Amazon' and $facts['os']['release']['major'] == '4' {
    $init_file = 'atlbitbucket.systemd.epp'
    $script_path = '/etc/systemd/system/atlbitbucket.service'
  } elsif $facts['os']['release']['major'] == '6' {
      $init_file = 'atlbitbucket.init.pp'
      $script_path = '/etc/init.d/atlbitbucket'
  } elsif $facts['os']['release']['major'] == '7' {
    $init_file = 'atlbitbucket.systemd.epp'
    $script_path = '/etc/systemd/system/atlbitbucket.service'
  } else {
    fail("You OS version is either far too old or far too bleeding edge: ${facts['os']['name']} ${facts['os']['release']['major']}")
  }

  # Determine if port is supplied, if not assume default port for database type
  if $bbs::db_port == undef or empty($bbs::db_port) {
    if $bbs::db_type == 'mysql' {
      $_db_port = '3306'
    } else {
      $_db_port = '5432'
    }
  } else {
    $_db_port = $bbs::db_port
  }

  if $bbs::db_type == 'mysql' {
    # If RHEL7 it uses MariaDB, which is not supported, but we can skip the check
    # -Dbitbucket.upgrade.fail.if.mysql.unsupported=false
    # Set db connection data
    $_java_args = "${bbs::java_args} -Dbitbucket.upgrade.fail.if.mysql.unsupported=false"
    $_db_driver = 'com.mysql.jdbc.Driver'
    $_db_url = "jdbc:mysql://${bbs::db_host}:${_db_port}/${bbs::db_name}?characterEncoding=utf8&useUnicode=true"
  } else {
    $_java_args = $bbs::java_args
    $_db_driver = 'com.psql.jdbc.Driver'
    $_db_url = "jdbc:postgresql://${bbs::db_host}:${_db_port}/${bbs::db_name}?characterEncoding=utf8&useUnicode=true"
  }

  # Configure the home/data/app directory for Bitbucket
  file { 'bbs_home_dir':
    ensure  => file,
    path    => "${bbs::bbs_install_dir}/atlassian-bitbucket-${bbs::version}/bin/set-bitbucket-home.sh",
    content => "BITBUCKET_HOME=${bbs::bbs_data_dir}\nexport BITBUCKET_HOME",
  }

  # JRE_HOME
  file { 'bbs_jre_home':
    ensure  => file,
    path    => "${bbs::bbs_install_dir}/atlassian-bitbucket-${bbs::version}/bin/set-jre-home.sh",
    content => epp('bbs/set-jre-home.sh.epp', {
      jre_home => $bbs::java_home,
    }),
  }

  #file { 'base_config':
  #  ensure  => file,
  #  path    => "${bbs::bbs_data_dir}/stash.cfg.xml",
  #  source  => 'puppet:///modules/bbs/stash.cfg.xml',
  #  replace => false,
  #}

  # Startup/Shutdown script
  file { 'init_script':
    ensure  => file,
    path    => $script_path,
    mode    => '0744',
    content => epp("bbs/${init_file}", {
      bbs_user        => $bbs::bbs_user,
      bbs_install_dir => $bbs::bbs_install_dir,
      bbs_data_dir    => $bbs::bbs_data_dir,
    }),
  }

  if $bbs::manage_db_settings {
    # Check if we have the required info
    if $bbs::db_name == undef or $bbs::db_host == undef or $bbs::db_user == undef or $bbs::db_password == undef {
      fail('When `manage_db_settings` is true you must provide `db_name`, `db_host`, `db_user`, and `db_password`')
    }

    file { 'db_settings':
      ensure  => file,
      path    => "${bbs::bbs_data_dir}/shared/bitbucket.properties",
      content => epp('bbs/bitbucket.properties.epp', {
        db_driver             => $_db_driver,
        db_url                => $_db_url,
        db_user               => $bbs::db_user,
        db_passwd             => $bbs::db_password,
        https                 => $bbs::https,
        keystore_path         => $bbs::keystore_path,
        keystore_password     => $bbs::keystore_password,
        keystore_key_password => $bbs::keystore_key_password,
        key_alias             => $bbs::key_alias,
      }),
    }

    # If MySQL we need the driver and set
    if $bbs::db_type == 'mysql' {
      archive { "/tmp/${bbs::mysql_driver_pkg}":
        ensure          => present,
        extract         => true,
        extract_command => "tar -zxf %s --strip-components 1 --exclude='lib*' */${bbs::mysql_driver_jar_name}",
        extract_path    => "${bbs::bbs_data_dir}/lib",
        source          => "${bbs::mysql_driver_source}/${bbs::mysql_driver_pkg}",
        creates         => "${bbs::bbs_data_dir}/lib/${bbs::mysql_driver_jar_name}",
        cleanup         => true,
        user            => $bbs::bbs_user,
        group           => $bbs::bbs_grp,
      }
    }
  }

  #file { 'java_args':
  #  ensure  => file,
  #  path    => "${bbs::bbs_install_dir}/atlassian-bitbucket-${bbs::version}/bin/setenv.sh",
  #  content => epp('bitbucket/setenv.sh.epp', {
  #    java_args => $_java_args,
  #    java_xms  => $bbs::jvm_xms,
  #    java_xmx  => $bbs::jvm_xmx,
  #  })
  #}
}
