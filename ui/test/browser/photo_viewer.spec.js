// The photo viewer in a real browser: what a DOM without layout can't
// show (the filmstrip's cut and scrolling, the badge's place, the stage's
// ratio by width, pan and zoom), and the hook's behaviour end to end on
// the preview, with its generated photos.
import {test, expect} from "@playwright/test"

const open = async (page, query = "") => {
  await page.goto(`/${query}`)
  // The hooks mount once LiveView has connected.
  await page.waitForFunction(() => window.liveSocket?.isConnected())
}

const viewer = (page, id) => page.locator(`#${id}`)
const box = async (locator) => (await locator.boundingBox())

test.describe("the stage and filmstrip", () => {
  test("shows the position on the photo's upper right", async ({page}) => {
    await open(page)
    const v = viewer(page, "many")
    await expect(v.locator(".pv-badge")).toHaveText("1 / 24")

    const stage = await box(v.locator("[data-slide='0'] .pv-frame"))
    const badge = await box(v.locator(".pv-badge"))
    expect(badge.y - stage.y).toBeLessThan(16)
    expect(stage.x + stage.width - (badge.x + badge.width)).toBeLessThan(16)
  })

  test("cuts the strip at the right edge when more photos follow", async ({page}) => {
    await open(page)
    const strip = viewer(page, "many").locator("[data-thumbs]")
    const edge = await box(strip)
    const sixth = await box(strip.locator("li").nth(5))
    // Five whole thumbnails, and part of the sixth.
    expect(sixth.x).toBeLessThan(edge.x + edge.width)
    expect(sixth.x + sixth.width).toBeGreaterThan(edge.x + edge.width)
  })

  test("a short set fits without a cut", async ({page}) => {
    await open(page)
    const strip = viewer(page, "captioned").locator("[data-thumbs]")
    expect(await strip.evaluate(s => s.scrollWidth <= s.clientWidth)).toBe(true)
  })

  test("clicking the last whole thumbnail brings the next ones into view", async ({page}) => {
    await open(page)
    const v = viewer(page, "many")
    const strip = v.locator("[data-thumbs]")
    await v.locator("[data-go='4']").click()
    await expect(v.locator(".pv-badge")).toHaveText("5 / 24")
    await expect.poll(() => strip.evaluate(s => s.scrollLeft)).toBeGreaterThan(0)

    // The current one is a whole thumbnail away from either edge.
    const edge = await box(strip)
    await expect.poll(async () => {
      const current = await box(v.locator("[data-go='4']"))
      return current.x + 2 * current.width <= edge.x + edge.width + 1
    }).toBe(true)
    await expect(v.locator("[data-go='5']")).toBeInViewport()
  })

  test("the stage is 4/5 in a narrow column and 4/3 when wide", async ({page}) => {
    await open(page, "?theme=neutral&width=300")
    let frame = await box(viewer(page, "many").locator("[data-slide='0'] .pv-frame"))
    expect(frame.width / frame.height).toBeCloseTo(4 / 5, 1)

    await open(page, "?theme=neutral&width=420")
    frame = await box(viewer(page, "many").locator("[data-slide='0'] .pv-frame"))
    expect(frame.width / frame.height).toBeCloseTo(4 / 3, 1)
  })
})

test.describe("moving between photos", () => {
  test("a thumbnail moves, with its caption and the position", async ({page}) => {
    await open(page)
    const v = viewer(page, "captioned")
    await v.locator("[data-go='1']").click()
    await expect(v.locator("[data-slide='1']")).toBeVisible()
    await expect(v.locator("[data-slide='0']")).toBeHidden()
    await expect(v.locator("[data-caption='1'] .pv-cap")).toBeVisible()
    await expect(v.locator(".pv-badge")).toHaveText("2 / 4")
    await expect(v.locator("[data-go='1']")).toHaveAttribute("aria-current", "true")
  })

  test("the arrow keys move and wrap, and focus follows", async ({page}) => {
    await open(page)
    const v = viewer(page, "captioned")
    await v.locator("[data-go='0']").focus()
    await page.keyboard.press("ArrowLeft")
    await expect(v.locator(".pv-badge")).toHaveText("4 / 4")
    await expect(v.locator("[data-go='3']")).toBeFocused()
    await page.keyboard.press("ArrowRight")
    await expect(v.locator(".pv-badge")).toHaveText("1 / 4")
  })

  test("a swipe on the photo moves, and doesn't open it", async ({page}) => {
    await open(page)
    const v = viewer(page, "captioned")
    await v.locator("[data-slide='0'] .pv-frame").scrollIntoViewIfNeeded()
    const frame = await box(v.locator("[data-slide='0'] .pv-frame"))
    const y = frame.y + frame.height / 2
    await page.mouse.move(frame.x + frame.width - 20, y)
    await page.mouse.down()
    await page.mouse.move(frame.x + 20, y, {steps: 5})
    await page.mouse.up()
    await expect(v.locator(".pv-badge")).toHaveText("2 / 4")
    await expect(v.locator("[data-lightbox]")).not.toHaveAttribute("open")
  })

  test("pushes on_change with each move", async ({page}) => {
    await open(page)
    await viewer(page, "many").locator("[data-go='2']").click()
    await expect(page.locator(".log li").first()).toHaveText("moved to 3")
  })
})

test.describe("the full view", () => {
  test("opens on the photo, loads its full size, and the arrows wrap", async ({page}) => {
    await open(page)
    const v = viewer(page, "captioned")
    await v.locator("[data-slide='0'] .pv-frame").click()
    const lightbox = v.locator("[data-lightbox]")
    await expect(lightbox).toHaveAttribute("open")
    await expect(lightbox.locator("[data-full='0'] img")).toHaveAttribute("src", "/assets/photos/1_large.svg")
    await expect(lightbox.locator("[data-full='0'] .pv-credit")).toContainText("Test photo 1")

    await lightbox.locator("[data-prev]").click()
    await expect(lightbox.locator("[data-counter]")).toHaveText("4 / 4")
    await expect(lightbox.locator("[data-full='3'] img")).toHaveAttribute("src", "/assets/photos/4_large.svg")
    await lightbox.locator("[data-next]").click()
    await expect(lightbox.locator("[data-counter]")).toHaveText("1 / 4")
  })

  test("Escape closes it and focus returns to the photo shown", async ({page}) => {
    await open(page)
    const v = viewer(page, "captioned")
    await v.locator("[data-slide='0'] .pv-frame").click()
    await page.keyboard.press("ArrowRight")
    await page.keyboard.press("Escape")
    await expect(v.locator("[data-lightbox]")).not.toHaveAttribute("open")
    await expect(v.locator("[data-slide='1'] .pv-frame")).toBeFocused()
  })

  test("zooms, pans within the photo, and fits again", async ({page}) => {
    await open(page)
    const v = viewer(page, "captioned")
    await v.locator("[data-slide='0'] .pv-frame").click()
    const lightbox = v.locator("[data-lightbox]")
    const img = lightbox.locator("[data-full='0'] img")
    await expect(img).toHaveJSProperty("complete", true)
    const fit = lightbox.locator("[data-zoom='fit']")
    await expect(fit).toBeDisabled()

    await page.keyboard.press("+")
    await expect(img).toHaveCSS("transform", /matrix\(1\.5, 0, 0, 1\.5/)
    await expect(fit).toBeEnabled()

    // A landscape photo at 1.5x is taller than the view, not wider: it
    // pans up and down, no further than its edge, and stays centred across.
    const view = await box(lightbox.locator("[data-full='0'] [data-view]"))
    const before = await box(img)
    await page.mouse.move(view.x + view.width / 2, view.y + view.height / 2)
    await page.mouse.down()
    await page.mouse.move(view.x + view.width / 2 + 2000, view.y + view.height / 2 + 2000, {steps: 4})
    await page.mouse.up()
    const after = await box(img)
    expect(after.x).toBeCloseTo(before.x, 0)
    expect(after.y).toBeGreaterThan(before.y)
    const top = await img.evaluate(i => {
      const r = i.parentElement.getBoundingClientRect()
      const fit = Math.min(r.width / i.naturalWidth, r.height / i.naturalHeight)
      return (r.height - i.naturalHeight * fit) / 2
    })
    // The photo's top edge (inside its contained box) stops at the view's.
    expect(after.y + top * 1.5).toBeCloseTo(view.y, 0)

    await page.keyboard.press("0")
    await expect(img).toHaveCSS("transform", "none")
    await expect(fit).toBeDisabled()
  })

  test("a move goes back to the fitted size", async ({page}) => {
    await open(page)
    const v = viewer(page, "captioned")
    await v.locator("[data-slide='0'] .pv-frame").click()
    const lightbox = v.locator("[data-lightbox]")
    await lightbox.locator("[data-zoom='in']").click()
    await expect(lightbox.locator("[data-full='0'] img")).not.toHaveCSS("transform", "none")
    await lightbox.locator("[data-next]").click()
    await lightbox.locator("[data-prev]").click()
    await expect(lightbox.locator("[data-full='0'] img")).toHaveCSS("transform", "none")
  })

  test("double-click zooms in and out", async ({page}) => {
    await open(page)
    const v = viewer(page, "captioned")
    await v.locator("[data-slide='0'] .pv-frame").click()
    const img = v.locator("[data-full='0'] img")
    await expect(img).toHaveJSProperty("complete", true)
    await v.locator("[data-full='0'] [data-view]").dblclick()
    await expect(img).not.toHaveCSS("transform", "none")
    await v.locator("[data-full='0'] [data-view]").dblclick()
    await expect(img).toHaveCSS("transform", "none")
  })
})

test.describe("details, one photo and none", () => {
  test("Details lists the photo's record, and a click outside closes it", async ({page}) => {
    await open(page)
    const v = viewer(page, "captioned")
    await v.getByRole("button", {name: "Details"}).click()
    const details = v.locator("[data-details]")
    await expect(details).toHaveAttribute("open")
    await expect(details.locator("[data-info='0'] dt")).toHaveText(["Photo", "Caption", "Creator", "License", "Source"])
    await page.mouse.click(5, 5)
    await expect(details).not.toHaveAttribute("open")
  })

  test("one photo has no strip and no position", async ({page}) => {
    await open(page)
    const v = viewer(page, "one")
    await expect(v.locator("[data-slide='0'] img")).toBeVisible()
    await expect(v.locator("[data-thumbs]")).toHaveCount(0)
    await expect(v.locator(".pv-badge")).toHaveCount(0)
  })

  test("no photos shows the label, and the actions when given", async ({page}) => {
    await open(page)
    await expect(viewer(page, "none").locator(".pv-empty")).toHaveText("No photos yet.")
    await expect(viewer(page, "none-actions").getByRole("link", {name: "Add images"})).toBeVisible()
  })
})
