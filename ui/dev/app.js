// The preview's bundle: LiveView, heartwood_ui's colocated hooks and CSS,
// imported the way an app imports them, and the preview's own styles.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks} from "phoenix-colocated/heartwood_ui"
import "phoenix-colocated/heartwood_ui/colocated.css"
import "./preview.css"

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {params: {_csrf_token: csrfToken}, hooks})
liveSocket.connect()
window.liveSocket = liveSocket
