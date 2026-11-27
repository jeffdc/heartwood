# Modules being replaced (see Heartwood.Guardrails.Retirements).
#
# A task that builds a replacement adds its entry here first, as its failing
# test, and deletes the old module in the same change:
#
#     %{retire: Heartwood.Guardrails.Old, replaced_by: Heartwood.Guardrails.New,
#       why: "a plan doc, PR or commit"}
#
# The test fails while both modules exist. Remove an entry once its old
# module is gone.
[]
