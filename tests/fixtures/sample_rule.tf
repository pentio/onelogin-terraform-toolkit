resource "onelogin_app_rules" "sample" {
  app_id   = "1"
  enabled  = true
  match    = "all"
  name     = "sample"
  position = 1

  actions {
    action = "set_amazonusername"
    value  = ["member_of"]
  }
  conditions {
    operator = "ri"
    source   = "has_role"
    value    = "1"
  }
}
