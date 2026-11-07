# Cross-cutting coverage lives in tests/PluginUpdateActivation.Integration.Tests.ps1:
# the worker imports built Core and executes its real manifest, API and registry
# collaborators in a new process. Source-only isolation cannot prove that contract.
