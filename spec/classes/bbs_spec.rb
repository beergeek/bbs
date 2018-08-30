require 'spec_helper'

describe 'bbs' do
  let :facts do
    {
      os: { 'family' => 'RedHat', 'release' => { 'major' => '7' } },
      osfamily: 'RedHat',
      operatingsystem: 'RedHat',
    }
  end

  context 'With defaults' do
    it do
      is_expected.to contain_class('bbs::install')
      is_expected.to contain_class('bbs::config')
      is_expected.to contain_class('bbs::service')
    end

    describe 'bbs::install' do
      it do
        is_expected.to contain_user('atlbitbucket').with(
          'ensure'      => 'present',
          'gid'         => 'atlbitbucket',
          'managehome'  => true,
          'shell'       => '/sbin/nologin',
        )
      end

      it do
        is_expected.to contain_group('atlbitbucket').with(
          'ensure'  => 'present',
        )
      end

      it do
        is_expected.to contain_file('/opt/atlassian/stash').with(
          'ensure'  => 'directory',
          'owner'   => 'atlbitbucket',
          'group'   => 'atlbitbucket',
          'mode'    => '0755',
        )
      end

      it do
        is_expected.to contain_file('/var/atlassian/application-data/stash').with(
          'ensure'  => 'directory',
          'owner'   => 'atlbitbucket',
          'group'   => 'atlbitbucket',
          'mode'    => '0755',
        )
      end

      it do
        is_expected.to contain_archive('/tmp/atlassian-bbs-6.6.1.tar.gz').with(
          'ensure'        => 'present',
          'extract'       => true,
          'extract_path'  => '/opt/atlassian/bbs',
          'source'        => 'https://product-downloads.atlassian.com/software/bbs/downloads/atlassian-bbs-6.6.1.tar.gz',
          'creates'       => '/opt/atlassian/bbs/atlassian-bbs-6.6.1',
          'cleanup'       => true,
          'user'          => 'atlbitbucket',
          'group'         => 'atlbitbucket',
        ).that_requires('File[/opt/atlassian/bbs]')
      end

      it do
        is_expected.to contain_file('/opt/atlassian/bbs/current').with(
          'ensure'  => 'link',
          'target'  => '/opt/atlassian/bbs/atlassian-bbs-6.6.1',
        )
      end
    end

    describe 'bbs::config' do
      it do
        is_expected.to contain_file_line('bbs_home_dir').with(
          'ensure'  => 'present',
          'path'    => '/opt/atlassian/bbs/atlassian-stash-5.13.1/atlassian-bbs/WEB-INF/classes/bbs-init.properties',
          'line'    => 'bbs.home=/var/atlassian/application-data/stash',
        )
      end

      it do
        is_expected.to contain_file('base_config').with(
          'ensure'  => 'file',
          'owner'   => 'bbs',
          'group'   => 'bbs',
          'mode'    => '0644',
          'source'  => 'puppet:///modules/bbs/stash.cfg.xml',
          'replace' => false,
        )
      end

      it do
        is_expected.to contain_file('init_script').with(
          'ensure' => 'file',
          'path'   => '/etc/systemd/system/bbs.service',
          'owner'  => 'bbs',
          'group'  => 'bbs',
          'mode'   => '0744',
        ).with_content(/User=bbs\nExecStart=\/opt\/atlassian\/bbs\/current\/bin\/start-bbs.sh\nExecStop=\/opt\/atlassian\/bbs\/current\/bin\/stop-bbs.sh/)
      end
    end

    describe 'bbs::service' do
      it do
        is_expected.to contain_service('bbs').with(
          'ensure' => 'running',
          'enable' => true,
        )
      end
    end
  end

  context 'bbs with MySQL database' do
    let :params do
      {
        manage_db_settings: true,
        db_type: 'mysql',
        db_host: 'mysql0.puppet.vm',
        db_name: 'bbsdb',
        db_user: 'bbs',
        db_password: 'password123',
      }
    end

    describe 'bbs::config' do
      it do
        is_expected.to contain_archive('/tmp/mysql-connector-java-5.1.46.tar.gz').with(
          'ensure'          => 'present',
          'extract'         => true,
          'extract_command' => "tar -zxf %s --strip-components 1 --exclude='lib*' */mysql-connector-java-5.1.46.jar",
          'extract_path'    => '/opt/atlassian/bbs/atlassian-bbs-6.6.1/lib',
          'source'          => 'https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-5.1.46.tar.gz',
          'creates'         => '/opt/atlassian/bbs/atlassian-bbs-6.6.1/lib/mysql-connector-java-5.1.46.jar',
          'cleanup'         => true,
          'user'            => 'bbs',
          'group'           => 'bbs',
        )
      end

      it do
        is_expected.to contain_file('java_args').with(
          'ensure'  => 'file',
          'path'    => '/opt/atlassian/bbs/atlassian-bbs-6.6.1/bin/setenv.sh',
          'owner'  => 'bbs',
          'group'  => 'bbs',
          'mode'   => '0644',
        ).with_content(/: \$\{JVM_SUPPORT_RECOMMENDED_ARGS:=" -Dbbs\.upgrade\.fail\.if\.mysql\.unsupported=false"\}/)
      end

      it do
        is_expected.to contain_file_line('db_driver').with(
          'ensure'  => 'present',
          'path'    => '/var/atlassian/application-data/bbs/bbs.cfg.xml',
          'line'    => "    <property name=\"hibernate.connection.driver_class\">com.mysql.jdbc.Driver</property>",
          'match'   => '^( |\\t)*<property name\\="hibernate.connection.driver_class">',
          'after'   => '^( |\\t)*<property name\\="bbs.jms.broker.uri">',
        ).that_requires("File[base_config]")
      end

      it do
        is_expected.to contain_file_line('db_password').with(
          'ensure'  => 'present',
          'path'    => '/var/atlassian/application-data/bbs/bbs.cfg.xml',
          'line'    => "    <property name=\"hibernate.connection.password\">password123</property>",
          'match'   => '^( |\\t)*<property name\\="hibernate.connection.password">',
          'after'   => '^( |\\t)*<property name\\="hibernate.connection.driver_class">',
        )
      end

      it do
        is_expected.to contain_file_line('db_url').with(
          'ensure'  => 'present',
          'path'    => '/var/atlassian/application-data/bbs/bbs.cfg.xml',
          'line'    => "    <property name=\"hibernate.connection.url\">jdbc:mysql://mysql0.puppet.vm/bbsdb?autoReconnect=true</property>",
          'match'   => '^( |\\t)*<property name\\="hibernate.connection.url">',
          'after'   => '^( |\\t)*<property name\\="hibernate.connection.password">',
        )
      end

      it do
        is_expected.to contain_file_line('db_user').with(
          'ensure'  => 'present',
          'path'    => '/var/atlassian/application-data/bbs/bbs.cfg.xml',
          'line'    => "    <property name=\"hibernate.connection.username\">bbs</property>",
          'match'   => '^( |\\t)*<property name\\="hibernate.connection.username">',
          'after'   => '^( |\\t)*<property name\\="hibernate.connection.url">',
        )
      end

      it do
        is_expected.to contain_file_line('db_dialect').with(
          'ensure'  => 'present',
          'path'    => '/var/atlassian/application-data/bbs/bbs.cfg.xml',
          'line'    => "    <property name=\"hibernate.dialect\">org.hibernate.dialect.MySQL5InnoDBDialect</property>",
          'match'   => '^( |\\t)*<property name\\="hibernate.dialect">',
          'after'   => '^( |\\t)*<property name\\="hibernate.connection.username">',
        )
      end
    end
  end
end
