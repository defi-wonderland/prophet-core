# Finality

## Introduction

Finality modules are responsible for executing actions when a request is finalized, such as notifying a contact about the response to a request.

Prophet's Finality modules:
- [CallbackModule](./finality/callback_module.md) sends a predefined callback to an external contract.
- [MultipleCallbacksModule](./finality/multiple_callbacks_module.md) that is similar to the `CallbackModule` but allows for multiple callbacks to be sent.

## Creating a Finality Module

To build a Finality module, inherit from `IFinalityModule` and the `Module` abstract contract, create the `RequestParameters` struct and define the logic in the `finalizeRequest` function. Most importantly, make sure to handle the finalization with and without a response.
