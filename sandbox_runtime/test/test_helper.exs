# Start the application for tests
{:ok, _} = Application.ensure_all_started(:sandbox_runtime)

ExUnit.start()
