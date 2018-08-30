class bbs::config {

  assert_private()

  File {
    owner   => $bbs::bbs_user,
    group   => $bbs::bbs_grp,
    mode    => '0644',
  }

  File_line {
    path    => "${bbs::bbs_data_dir}/bamboo.cfg.xml",
  }

  if $facts['os']['name'] == 'Amazon' and $facts['os']['release']['major'] == '4' {
    $init_file = 'stash.systemd.epp'
    $script_path = '/etc/systemd/system/stash.service'
  } elsif $facts['os']['release']['major'] == '6' {
      $init_file = 'stash.init.pp'
      $script_path = '/etc/init.d/stash'
  } elsif $facts['os']['release']['major'] == '7' {
    $init_file = 'stash.systemd.epp'
    $script_path = '/etc/systemd/system/stash.service'
  } else {
    fail("You OS version is either far too old or far too bleeding edge: ${facts['os']['name']} ${facts['os']['release']['major']}")
  }

  if $bbs::db_type == 'mysql' {
    # If RHEL7 it uses MariaDB, which is not supported, but we can skip the check
    # -Dbamboo.upgrade.fail.if.mysql.unsupported=false
    # Set db connection data
    $_java_args = "${bbs::java_args} -Dbamboo.upgrade.fail.if.mysql.unsupported=false"
    $_db_driver = 'com.mysql.jdbc.Driver'
    $_db_hibernate = 'org.hibernate.dialect.MySQL5InnoDBDialect'
    $_db_url = "jdbc:mysql://${bbs::db_host}/${bbs::db_name}?autoReconnect=true"
  } else {
    $_java_args = $bbs::java_args
    $_db_driver = 'com.mysql.jdbc.Driver'
    $_db_hibernate = 'org.hibernate.dialect.PostgreSQL82Dialect'
    $_db_url = "jdbc:postgresql://${bbs::db_host}/${bbs::db_name}?autoReconnect=true"
  }

  # Configure the home/data/app directory for Bamboo
  file_line { 'bamboo_home_dir':
    ensure => present,
    path   => "${bbs::bbs_install_dir}/atlassian-bitbucket-${bbs::version}/bin/set-bitbucket-home.sh",
    line   => "  BITBUCKET_HOME=${bbs::bbs_data_dir}",
    match  => "\s*BITBUCKET_HOME=",
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
      bamboo_user        => $bbs::bbs_user,
      bamboo_install_dir => "${bbs::bbs_install_dir}/current",
    }),
  }

  if $bbs::manage_db_settings {
    # Check if we have the required info
    if $bbs::db_name == undef or $bbs::db_host == undef or $bbs::db_user == undef or $bbs::db_password == undef {
      fail('When `manage_db_settings` is true you must provide `db_name`, `db_host`, `db_user`, and `db_password`')
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

    # If MySQL we need the driver and set
    if $bbs::db_type == 'mysql' {
      archive { "/tmp/${bbs::mysql_driver_pkg}":
        ensure          => present,
        extract         => true,
        extract_command => "tar -zxf %s --strip-components 1 --exclude='lib*' */${bbs::mysql_driver_jar_name}",
        extract_path    => "${bbs::bbs_install_dir}/atlassian-bamboo-${bbs::version}/lib",
        source          => "${bbs::mysql_driver_source}/${bbs::mysql_driver_pkg}",
        creates         => "${bbs::bbs_install_dir}/atlassian-bamboo-${bbs::version}/lib/${bbs::mysql_driver_jar_name}",
        cleanup         => true,
        user            => $bbs::bbs_user,
        group           => $bbs::bbs_grp,
      }
    }

    # Database connector config
    file_line { 'db_driver':
      ensure  => present,
      line    => "    <property name=\"hibernate.connection.driver_class\">${_db_driver}</property>",
      match   => '^( |\t)*<property name\="hibernate.connection.driver_class">',
      after   => '^( |\t)*<property name\="bamboo.jms.broker.uri">',
      require => File['base_config'],
    }

    file_line { 'db_password':
      ensure  => present,
      line    => "    <property name=\"hibernate.connection.password\">${bbs::db_password}</property>",
      match   => '^( |\t)*<property name\="hibernate.connection.password">',
      after   => '^( |\t)*<property name\="hibernate.connection.driver_class">',
      require => File_line['db_driver'],
    }

    file_line { 'db_url':
      ensure  => present,
      line    => "    <property name=\"hibernate.connection.url\">${_db_url}</property>",
      match   => '^( |\t)*<property name\="hibernate.connection.url">',
      after   => '^( |\t)*<property name\="hibernate.connection.password">',
      require => File_line['db_password'],
    }

    file_line { 'db_user':
      ensure  => present,
      line    => "    <property name=\"hibernate.connection.username\">${bbs::db_user}</property>",
      match   => '^( |\t)*<property name\="hibernate.connection.username">',
      after   => '^( |\t)*<property name\="hibernate.connection.url">',
      require => File_line['db_url'],
    }

    file_line { 'db_dialect':
      ensure  => present,
      line    => "    <property name=\"hibernate.dialect\">${_db_hibernate}</property>",
      match   => '^( |\t)*<property name\="hibernate.dialect">',
      after   => '^( |\t)*<property name\="hibernate.connection.username">',
      require => File_line['db_user'],
    }
  }

  file { 'java_args':
    ensure  => file,
    path    => "${bbs::bbs_install_dir}/atlassian-bamboo-${bbs::version}/bin/setenv.sh",
    content => epp('bamboo/setenv.sh.epp', {
      java_args => $_java_args,
      java_xms  => $bbs::jvm_xms,
      java_xmx  => $bbs::jvm_xmx,
    })
  }
}
