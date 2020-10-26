Pod::Spec.new do |s|
  s.name             = 'PocketPurchases'
  s.version          = '0.1.4'
  s.summary          = 'The Pocket Ninja Purchases client.'

  s.homepage         = 'https://github.com/pocket-ninja/pocket-purchases'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'egor mihneivch' => 'cursed.elfenlaid@gmail.com' }
  s.source           = { :git => 'git@github.com:pocket-ninja/pocket-purchases.git', :tag => s.version.to_s }

  s.ios.deployment_target = '12.0'
  s.swift_version = '5.3'
  s.static_framework = true

  s.source_files = 'PocketPurchases/Sources/**/*'

  s.dependency 'SwiftyStoreKit', '~> 0.16'
  s.dependency 'RxSwift', '~> 5'
  s.dependency 'RxRelay'
end
