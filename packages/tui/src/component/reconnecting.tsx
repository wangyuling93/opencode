import { RGBA } from "@opentui/core"
import { overlayPlate, useTheme, useThemes } from "../context/theme"
import { Spinner } from "./spinner"

export function Reconnecting(props: { managed?: boolean }) {
  const theme = useTheme("elevated")
  const { transparent } = useThemes()

  return (
    <box
      position="absolute"
      zIndex={10_000}
      top={0}
      right={0}
      bottom={0}
      left={0}
      backgroundColor={transparent() ? RGBA.fromInts(0, 0, 0, 0) : RGBA.fromInts(0, 0, 0, 150)}
      alignItems="center"
      justifyContent="center"
    >
      <box
        width={48}
        maxWidth="90%"
        flexDirection="column"
        backgroundColor={overlayPlate(theme.background.default, transparent())}
        paddingTop={1}
        paddingBottom={1}
        paddingLeft={2}
        paddingRight={2}
        gap={1}
      >
        <Spinner color={theme.text.default}>{props.managed ? "Restarting service..." : "Connection lost..."}</Spinner>
        <text fg={theme.text.subdued}>
          {props.managed
            ? "Your session will resume automatically."
            : "Reconnecting to the server automatically."}
        </text>
      </box>
    </box>
  )
}
