terraform {
  required_providers {
    onelogin = {
      source  = "onelogin/onelogin"
      version = "0.4.9"  
    }
  }
}

provider "onelogin" {
  apikey_auth = var.onelogin_access_token
}
