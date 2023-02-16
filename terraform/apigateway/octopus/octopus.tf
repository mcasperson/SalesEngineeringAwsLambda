terraform {
  required_providers {
    octopusdeploy = { source = "OctopusDeployLabs/octopusdeploy", version = "0.10.3" }
  }
}

provider "octopusdeploy" {
  address  = "${var.octopus_server}"
  api_key  = "${var.octopus_apikey}"
  space_id = "${var.octopus_space_id}"
}

variable "octopus_server" {
  type        = string
  nullable    = false
  sensitive   = false
  description = "The URL of the Octopus server e.g. https://myinstance.octopus.app."
}

variable "octopus_apikey" {
  type        = string
  nullable    = false
  sensitive   = true
  description = "The API key used to access the Octopus server. See https://octopus.com/docs/octopus-rest-api/how-to-create-an-api-key for details on creating an API key."
}

variable "octopus_space_id" {
  type        = string
  nullable    = false
  sensitive   = false
  description = "The ID of the Octopus space to populate."
}

data "octopusdeploy_environments" "environment_production" {
  ids          = null
  partial_name = "Production"
  skip         = 0
  take         = 1
}

data "octopusdeploy_environments" "environment_development" {
  ids          = null
  partial_name = "Development"
  skip         = 0
  take         = 1
}

data "octopusdeploy_library_variable_sets" "library_variable_set_octopub" {
  ids          = null
  partial_name = "Octopub"
  skip         = 0
  take         = 1
}

data "octopusdeploy_lifecycles" "default" {
  ids          = []
  partial_name = "Default Lifecycle"
  skip         = 0
  take         = 1
}

data "octopusdeploy_worker_pools" "workerpool_hosted_ubuntu" {
  name = "Hosted Ubuntu"
  ids  = null
  skip = 0
  take = 1
}


resource "octopusdeploy_project_group" "project_group_infrastructure" {
  name        = "Infrastructure"
  description = "Builds the API Gateway."
}

resource "octopusdeploy_project" "project_api_gateway" {
  name                                 = "API Gateway"
  auto_create_release                  = false
  default_guided_failure_mode          = "EnvironmentDefault"
  default_to_skip_if_already_installed = false
  description                          = "Deploys a shared API Gateway. This project is created and managed by the [Octopus Terraform provider](https://registry.terraform.io/providers/OctopusDeployLabs/octopusdeploy/latest/docs). The Terraform files can be found in the [GitHub repo](https://github.com/mcasperson/OctopusBuilder-LAM)."
  discrete_channel_release             = false
  is_disabled                          = false
  is_version_controlled                = false
  lifecycle_id                         = "${data.octopusdeploy_lifecycles.default.lifecycles[0].id}"
  project_group_id                     = "${octopusdeploy_project_group.project_group_infrastructure.id}"
  included_library_variable_sets       = ["${data.octopusdeploy_library_variable_sets.library_variable_set_octopub.library_variable_sets[0].id}"]
  tenanted_deployment_participation    = "Untenanted"

  connectivity_policy {
    allow_deployments_to_no_targets = false
    exclude_unhealthy_targets       = false
    skip_machine_behavior           = "SkipUnavailableMachines"
  }
}

resource "octopusdeploy_deployment_process" "deployment_process_project_api_gateway" {
  project_id = "${octopusdeploy_project.project_api_gateway.id}"

  step {
    condition           = "Success"
    name                = "Create API Gateway"
    package_requirement = "LetOctopusDecide"
    start_trigger       = "StartAfterPrevious"

    action {
      action_type                        = "Octopus.AwsRunCloudFormation"
      name                               = "Create API Gateway"
      condition                          = "Success"
      run_on_server                      = true
      is_disabled                        = false
      can_be_used_for_project_versioning = false
      is_required                        = false
      worker_pool_id                     = "${data.octopusdeploy_worker_pools.workerpool_hosted_ubuntu.worker_pools[0].id}"
      properties                         = {
        "Octopus.Action.Aws.CloudFormation.Tags" = jsonencode([
          {
            "value" = "#{Octopus.Environment.Name | Replace \" .*\" \"\"}"
            "key" = "Environment"
          },
          {
            "key" = "DeploymentProject"
            "value" = "API_Gateway"
          },
        ])
        "Octopus.Action.Aws.CloudFormationTemplateParameters" = jsonencode([])
        "Octopus.Action.Aws.Region" = "#{AWS.Region}"
        "Octopus.Action.Aws.CloudFormationStackName" = "#{AWS.CloudFormation.ApiGatewayStack}"
        "Octopus.Action.Aws.CloudFormationTemplate" = <<-EOT
        Resources:
          RestApi:
            Type: 'AWS::ApiGateway::RestApi'
            Properties:
              Description: My API Gateway
              Name: Octopub
              BinaryMediaTypes:
                - '*/*'
              EndpointConfiguration:
                Types:
                  - REGIONAL
          Health:
            Type: 'AWS::ApiGateway::Resource'
            Properties:
              RestApiId:
                Ref: RestApi
              ParentId:
                'Fn::GetAtt':
                  - RestApi
                  - RootResourceId
              PathPart: health
          Api:
            Type: 'AWS::ApiGateway::Resource'
            Properties:
              RestApiId:
                Ref: RestApi
              ParentId:
                'Fn::GetAtt':
                  - RestApi
                  - RootResourceId
              PathPart: api
          Web:
            Type: 'AWS::ApiGateway::Resource'
            Properties:
              RestApiId: !Ref RestApi
              ParentId: !GetAtt
                - RestApi
                - RootResourceId
              PathPart: '{proxy+}'
        Outputs:
          RestApi:
            Description: The REST API
            Value: !Ref RestApi
          RootResourceId:
            Description: ID of the resource exposing the root resource id
            Value:
              'Fn::GetAtt':
                - RestApi
                - RootResourceId
          Health:
            Description: ID of the resource exposing the health endpoints
            Value: !Ref Health
          Api:
            Description: ID of the resource exposing the api endpoint
            Value: !Ref Api
          Web:
            Description: ID of the resource exposing the web app frontend
            Value: !Ref Web
        EOT
        "Octopus.Action.Aws.CloudFormationTemplateParametersRaw" = jsonencode([])
        "Octopus.Action.Aws.TemplateSource" = "Inline"
        "Octopus.Action.Aws.WaitForCompletion" = "True"
        "Octopus.Action.Aws.AssumeRole" = "False"
        "Octopus.Action.AwsAccount.Variable" = "AWS.Account"
        "Octopus.Action.AwsAccount.UseInstanceRole" = "False"
      }
      environments                       = []
      excluded_environments              = []
      channels                           = []
      tenant_tags                        = []
      features                           = []
    }

    properties   = {}
    target_roles = []
  }
}