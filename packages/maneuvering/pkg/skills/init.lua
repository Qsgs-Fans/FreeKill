local prefix = "packages.maneuvering.pkg.skills."
if UsingNewCore then
  prefix = "packages.freekill-core.maneuvering.pkg.skills."
end

return {
  require(prefix .. "thunder__slash"),
  require(prefix .. "fire__slash"),
  require(prefix .. "analeptic"),
  require(prefix .. "iron_chain"),
  require(prefix .. "fire_attack"),
  require(prefix .. "supply_shortage"),
  require(prefix .. "guding_blade"),
  require(prefix .. "fan"),
  require(prefix .. "vine"),
  require(prefix .. "silver_lion"),
  require(prefix .. "hualiu"),

  require(prefix .. "recast"),
}
