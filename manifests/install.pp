#
class bbs::install () {

  assert_private()

  if $bbs::manage_user {
    user { $bbs::bbs_user:
      ensure     => present,
      gid        => $bbs::bbs_grp,
      managehome => true,
      shell      => '/sbin/nologin',
    }
  }

  if $bbs::manage_grp {
    group { $bbs::bbs_grp:
      ensure => present,
    }
  }

  file { [$bbs::bbs_install_dir, $bbs::bbs_data_dir]:
    ensure => directory,
    owner  => $bbs::bbs_user,
    group  => $bbs::bbs_grp,
    mode   => '0755',
  }

  archive { "/tmp/atlassian-bitbucket-${bbs::version}.tar.gz":
    ensure       => present,
    extract      => true,
    extract_path => $bbs::bbs_install_dir,
    source       => "${bbs::source_location}/atlassian-bitbucket-${bbs::version}.tar.gz",
    creates      => "${bbs::bbs_install_dir}/atlassian-bitbucket-${bbs::version}",
    cleanup      => true,
    user         => $bbs::bbs_user,
    group        => $bbs::bbs_grp,
    require      => File[$bbs::bbs_install_dir],
  }

  file { "${bbs::bbs_install_dir}/current":
    ensure => link,
    target => "${bbs::bbs_install_dir}/atlassian-bbs-${bbs::version}",
  }

}
