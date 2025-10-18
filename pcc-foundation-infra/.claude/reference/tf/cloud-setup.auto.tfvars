org_id          = "146990108557"
billing_account = "01AFEA-2B972B-00C55F"

/*
The folder map is limited to three levels
The environment names are "Production", "Non Production" and "Development"
they are potentially referenced in iam.tf, service_projects.tf, and projects.tf
if you rename, e.g. "Production" to "Prod", you will need to find references like
module.cs-folders-level-1["Team 1/Production"].ids["Production"] and rename to
module.cs-folders-level-1["Team 1/Prod"].ids["Prod"]
*/
folders = {
  "Production" : {},
  "Non-Production" : {},
  "Development" : {},
}
application_enabled_folder_paths = [
  "Production",
  "Non-Production",
  "Development",
]
