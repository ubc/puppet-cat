class cat (
  $db_host = 'localhost',
  $db_user = 'cat',
  $db_password = 'catisthesecret',
  $db_name = 'currimap',
  $db_rootpwd = 'somethingmoresecret',
  $revision = 'master',
  $code_base = '/tmp/cat',
  $ldap_enabled = 'N',
  $temp_dir = '/tmp',
  $log_file = '/var/log/currimap.log',
  $app = 'cat',
  $site = $fqdn,
  $cas_login = undef,
  $cas_validation = undef,
  $port     = 80,
  $host     = $fqdn,
  $server_name  = $fqdn,
  $ssl      = false,
  $ssl_cert = undef,
  $ssl_key  = undef,
  $ssl_cert_location = undef,
  $ssl_key_location = undef,
  $git_repo = "https://github.com/usaskulc/cat.git",
) {
  class { '::mysql::server':
    root_password => $db_rootpwd, 
    override_options => {
      'mysqld' => {
    	'bind_address' => '0.0.0.0',
      }
    }
  }

  mysql::db { $db_name:
    user     => $db_user,
    password => $db_password,
    host     => $db_host,
    grant    => ['all'],
  }

  package {'ant':
    ensure => installed,
  }

  class { 'tomcat': }


  tomcat::vhost { $host:
    contexts => { 'base' => 'ROOT', 'path' => '' },
  }

  vcsrepo { "${code_base}":
    ensure   => present,
    provider => git,
    require  => [ Package["git"] ],
    source   => $git_repo,
    revision => $revision,
    notify => Exec['compile_war_file'],
  } ->

  file { "${code_base}/cat/conf/example.yourdomain.edu/context.xml":
    ensure => present,
    content => template('cat/context.xml.erb'),
    notify => Exec['compile_war_file'],
  } ->
  
  file { "${code_base}/cat/conf/example.yourdomain.edu/database.properties":
    ensure => present,
    content => template('cat/database.properties.erb'),
    notify => Exec['compile_war_file'],
  } ->
  
  file { "${code_base}/cat/conf/example.yourdomain.edu/hibernate.cfg.xml":
    ensure => present,
    content => template('cat/hibernate.cfg.xml.erb'),
    notify => Exec['compile_war_file'],
  } ->

  file { "${code_base}/cat/conf/example.yourdomain.edu/currimap.properties":
    ensure => present,
    content => template('cat/currimap.properties.erb'),
    notify => Exec['compile_war_file'],
  } ->
  
  file { "${code_base}/cat/conf/example.yourdomain.edu/log4j.properties":
    ensure => present,
    content => template('cat/log4j.properties.erb'),
    notify => Exec['compile_war_file'],
  } ->

  file { "${code_base}/cat/conf/example.yourdomain.edu/web.xml":
    ensure => present,
    content => template('cat/web.xml.erb'),
    notify => Exec['compile_war_file'],
  }

  exec { "compile_war_file": 
    command => "ant dist",
    cwd => "${code_base}/cat",
    path => '/usr/bin:/bin',
    logoutput   => on_failure,
    refreshonly => true,
  } 

  file { "${tomcat::sites_dir}/${site}/${app}.war":
    ensure => present,
    source => "${code_base}/cat/cat.war",
    notify => Exec["clean_${tomcat::sites_dir}/${site}/${app}"],
  }

  exec { "clean_${tomcat::sites_dir}/${site}/${app}":
    command     => "rm -rf ${app} ; mkdir ${app} ; unzip ${app}.war -d ${app}/",
    cwd         => "${tomcat::sites_dir}/${site}",
    path        => '/usr/bin:/bin',
    user        => tomcat,
    group       => tomcat,
    logoutput   => on_failure,
    refreshonly => true,
    notify      => Class['tomcat::service'],
  }
 
  class { 'apache':}
  class { 'apache::mod::proxy_ajp':}

  if ($port == 80 and $ssl == true) {
    $port_real = 443
  } else {
    $port_real = $port
  }

  if ($ssl == true) {
    apache::vhost { "${host}_non-ssl":
      servername      => $host,
      port            => '80',
      docroot         => "${tomcat::sites_dir}/${site}/${app}",
      redirect_status => ['permanent'],
      redirect_dest   => ["https://$host/"],
    }

    file { $ssl_cert_location:
      ensure => present,
      source => $ssl_cert,
      mode => 644,
      owner => 'root',
      group => 'root',
      notify => Class['apache::service'],
    }

    file { $ssl_key_location:
      ensure => present,
      source => $ssl_key,
      mode => 600,
      owner => 'root',
      group => 'root',
      notify => Class['apache::service'],
    }
  }

  apache::vhost { $host:
    port =>  $port_real,
    docroot => "${tomcat::sites_dir}/${site}/${app}",
    proxy_pass  => [{'path' => '/cat', 'url' => 'ajp://localhost:8009/cat'}],
    ssl => $ssl,
    ssl_cert => $ssl_cert_location,
    ssl_key => $ssl_key_location,
    override => 'All',
    redirect_source => ['/'],
    redirect_dest => ['/cat'],
    redirect_status => ['permanent'],
  }

  firewall { '100 allow http and https access':
    port   => [80,443],
    proto  => tcp,
    action => accept,
  }

}
