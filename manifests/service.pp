class bbs::service {

  service { 'atlbitbucket':
    ensure => running,
    enable => true,
  }
}
