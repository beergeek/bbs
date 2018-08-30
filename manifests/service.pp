class bbs::service {

  service { 'altbitbucket':
    ensure => running,
    enable => true,
  }
}
