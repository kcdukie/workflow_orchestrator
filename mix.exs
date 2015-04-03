defmodule CloudOS.WorkflowOrchestrator.Mixfile do
  use Mix.Project

  def project do
    [app: :cloudos_workflow_orchestrator,
     version: "0.0.1",
     elixir: "~> 1.0",
     deps: deps]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [
      mod: { CloudOS.WorkflowOrchestrator, [] },
      applications: [:logger, :cloudos_messaging, :cloudos_manager_api]
    ]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type `mix help deps` for more examples and options
  defp deps do
    [
      {:poison, "~> 1.3.1"},
      {:cloudos_messaging, git: "https://#{System.get_env("GITHUB_OAUTH_TOKEN")}:x-oauth-basic@github.com/UmbrellaCorporation-SecretProjectLab/cloudos_messaging.git", ref: "760a267355ef6b3e3f601a44f52383516bfb5a51", override: true},
      {:cloudos_manager_api, git: "https://#{System.get_env("GITHUB_OAUTH_TOKEN")}:x-oauth-basic@github.com/UmbrellaCorporation-SecretProjectLab/cloudos_manager_api.git", ref: "77bdb8a5c9a176fd307e2c77e63cab0215b657c3", override: true},

      {:timex, "~> 0.12.9"},
      {:timex_extensions, git: "https://#{System.get_env("GITHUB_OAUTH_TOKEN")}:x-oauth-basic@github.com/UmbrellaCorporation-SecretProjectLab/timex_extensions.git", ref: "master", override: true},

      #test dependencies
      {:exvcr, github: "parroty/exvcr", override: true},
      {:meck, "0.8.2", override: true}
    ]
  end
end
