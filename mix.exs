defmodule ConnectFour.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Test
      test_coverage: [tool: ExCoveralls],
      preferred_CLI_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.circle": :test
      ],

      # Docs
      name: "Connect Four",
      source_url: "https://github.com/rjdellecese/connect_four",
      homepage_url: "https://github.com/rjdellecese/connect_four"
    ]
  end

  # Dependencies listed here are available only for this
  # project and cannot be accessed from applications inside
  # the apps folder.
  #
  # Run "mix help deps" for examples and options.
  defp deps do
    [
      {:credo, "~> 1.0.0", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.10", only: :test}
    ]
  end
end
