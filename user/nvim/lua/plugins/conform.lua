return {
	{
		"stevearc/conform.nvim",
		opts = {
			lsp_fallback = true,

			formatters_by_ft = {
				lua = { "stylua" },

				javascript = { "prettier" },
				css = { "prettier" },
				html = { "prettier" },

				sh = { "shfmt" },
			},
		},
	},
}
