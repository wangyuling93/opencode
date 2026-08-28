/// <reference types="@solidjs/start/env" />

declare module "solid-js/web" {
  interface RequestEvent {
    locals: Record<string | number | symbol, any>
  }
}

export declare module "@solidjs/start/server" {
  export type APIEvent = { request: Request }
}
