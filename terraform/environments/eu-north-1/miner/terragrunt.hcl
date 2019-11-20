terraform {
  source = "../../../modules/spacemesh-miner/"
}

dependencies {
  paths = [ "../initfactory/" ]
}

include {
  path = find_in_parent_folders()
}

# vim:filetype=terraform ts=2 sw=2 et:
