-- Late-bound access to server services so they can call each other without circular requires.
-- Filled by the bootstrap script before any service starts.

local Registry: { [string]: any } = {}

return Registry
