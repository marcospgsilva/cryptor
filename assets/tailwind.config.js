const colors = require('tailwindcss/colors')

module.exports = {
  purge: {
    enabled: process.env.NODE_ENV === "production",
    content: [
      "../lib/**/*.eex",
      "../lib/**/*.leex",
      "../lib/**/*_view.ex"
    ],
    options: {
      whitelist: [/phx/, /nprogress/]
    }
  },
  theme: {
    extend: {
      colors: {
        'light-blue': colors.lightBlue,
        cyan: colors.cyan,
      },
      backgroundImage: _theme => ({
        'cryptor': "url('/images/cryptor.jpg')",
      })
    },
    backgroundColor: theme => ({
      ...theme('colors'),
      'primary': '#181B23',
      'secondary': '#25262E'
    })
  },
  variants: {
    extend: {
      borderWidth: ['hover'],
    }
  },
  plugins: [require('@tailwindcss/forms')],
}