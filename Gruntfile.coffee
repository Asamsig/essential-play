#global module:false

path    = require 'path'
process = require 'child_process'
yaml    = require 'js-yaml'
fs      = require 'fs'

"use strict"

module.exports = (grunt) ->
  minify = grunt.option('minify') ? false

  grunt.loadNpmTasks "grunt-browserify"
  grunt.loadNpmTasks "grunt-contrib-clean"
  grunt.loadNpmTasks "grunt-contrib-connect"
  grunt.loadNpmTasks "grunt-contrib-less"
  grunt.loadNpmTasks "grunt-contrib-watch"
  # grunt.loadNpmTasks "grunt-exec"
  grunt.loadNpmTasks "grunt-css-url-embed"

  joinLines = (lines) ->
    lines.split(/[ \r\n]+/).join(" ")

  meta = yaml.safeLoad(fs.readFileSync('./src/meta/metadata.yaml', 'utf8'))

  unless typeof meta.filenameStem == "string"
    grunt.fail.fatal("'filename' in metadata must be a string")

  unless !meta.exercisesRepo || typeof meta.exercisesRepo == "string"
    grunt.fail.fatal("'exercisesRepo' in metadata must be a string or null")

  unless Array.isArray(meta.pages)
    grunt.fail.fatal("'pages' in metadata must be an array of strings")

  grunt.initConfig
    clean:
      main:
        src: "dist"

    less:
      main:
        options:
          paths: [
            "node_modules"
            "lib/css"
            "src/css"
          ]
          compress: minify
          yuicompress: minify
        files:
          "dist/temp/main.noembed.css" : "lib/css/main.less"

    cssUrlEmbed:
      main:
        options:
          baseDir: "."
        files:
          "dist/temp/main.css" : "dist/temp/main.noembed.css"

    browserify:
      main:
        src:  "lib/js/main.coffee"
        dest: "dist/temp/main.js"
        cwd:  "."
        options:
          watch: false
          transform: if minify
            [ 'coffeeify', [ 'uglifyify', { global: true } ] ]
          else
            [ 'coffeeify' ]
          browserifyOptions:
            debug: false
            extensions: [ '.coffee' ]

    watchImpl:
      options:
        livereload: true
      css:
        files: [
          "lib/css/**/*"
        ]
        tasks: [
          "less"
          "cssUrlEmbed"
          "pandoc:html"
        ]
      js:
        files: [
          "lib/js/**/*"
        ]
        tasks: [
          "browserify"
          "pandoc:html"
        ]
      templates:
        files: [
          "lib/templates/**/*"
        ]
        tasks: [
          "pandoc:html"
          "pandoc:pdf"
          "pandoc:epub"
        ]
      pages:
        files: [
          "src/pages/**/*"
        ]
        tasks: [
          "pandoc:html"
          "pandoc:pdf"
          "pandoc:epub"
        ]
      metadata:
        files: [
          "src/meta/**/*"
        ]
        tasks: [
          "pandoc:html"
          "pandoc:pdf"
          "pandoc:epub"
        ]

    connect:
      server:
        options:
          port: 4000
          base: 'dist'

  grunt.renameTask "watch", "watchImpl"

  grunt.registerTask "pandoc", "Run pandoc", (target) ->
    done = this.async()

    target ?= "html"

    switch target
      when "pdf"
        output   = "--output=dist/#{meta.filenameStem}.pdf"
        template = "--template=lib/templates/template.tex"
        filters  = joinLines """
                     --filter=lib/filters/pdf/callout.coffee
                     --filter=lib/filters/pdf/columns.coffee
                   """
        extras   = ""
        metadata = "src/meta/pdf.yaml"

      when "html"
        output   = "--output=dist/#{meta.filenameStem}.html"
        template = "--template=lib/templates/template.html"
        filters  = joinLines """
                     --filter=lib/filters/html/tables.coffee
                   """
        extras   = ""
        metadata = "src/meta/html.yaml"

      when "epub"
        output   = "--output=dist/#{meta.filenameStem}.epub"
        template = "--epub-stylesheet=dist/temp/main.css"
        filters  = ""
        extras   = "--epub-cover-image=src/covers/epub-cover.png"
        metadata = "src/meta/epub.yaml"

      when "json"
        output   = "--output=dist/#{meta.filenameStem}.json"
        template = ""
        filters  = ""
        extras   = ""
        metadata = ""

      else
        grunt.log.error("Bad pandoc format: #{target}")

    command = joinLines """
      pandoc
      --smart
      #{output}
      #{template}
      --from=markdown+grid_tables+multiline_tables+fenced_code_blocks+fenced_code_attributes+yaml_metadata_block+implicit_figures
      --latex-engine=xelatex
      #{filters}
      --chapters
      --number-sections
      --table-of-contents
      --highlight-style tango
      --standalone
      --self-contained
      #{extras}
      src/meta/metadata.yaml
      #{metadata}
      #{meta.pages.join(" ")}
    """

    grunt.log.write("Running: #{command}")

    pandoc = process.exec(command)

    pandoc.stdout.on 'data', (d) ->
      grunt.log.write(d)
      return

    pandoc.stderr.on 'data', (d) ->
      grunt.log.error(d)
      return

    pandoc.on 'error', (err) ->
      grunt.log.error("Failed with: #{err}")
      done(false)

    pandoc.on 'exit', (code) ->
      if code == 0
        grunt.verbose.subhead("pandoc exited with code 0")
        done()
      else
        grunt.log.error("pandoc exited with code #{code}")
        done(false)

    return

  grunt.registerTask "exercises", "Download and build exercises", (target) ->
    unless meta.exercisesRepo
      return

    done = this.async()

    grunt.log.write("Running: #{command}")

    pandoc = process.exec(command)

    pandoc.stdout.on 'data', (d) ->
      grunt.log.write(d)
      return

    pandoc.stderr.on 'data', (d) ->
      grunt.log.error(d)
      return

    pandoc.on 'error', (err) ->
      grunt.log.error("Failed with: #{err}")
      done(false)

    pandoc.on 'exit', (code) ->
      if code == 0
        grunt.verbose.subhead("pandoc exited with code 0")
        done()
      else
        grunt.log.error("pandoc exited with code #{code}")
        done(false)

    return

  grunt.registerTask "json", [
    "pandoc:json"
  ]

  grunt.registerTask "html", [
    "less"
    "cssUrlEmbed"
    "browserify"
    "pandoc:html"
  ]

  grunt.registerTask "pdf", [
    "pandoc:pdf"
  ]

  grunt.registerTask "epub", [
    "less"
    "cssUrlEmbed"
    "pandoc:epub"
  ]

  grunt.registerTask "all", [
    "less"
    "cssUrlEmbed"
    "browserify"
    "pandoc:html"
    "pandoc:pdf"
    "pandoc:epub"
  ]

  # grunt.registerTask "zip", [
  #   "all"
  #   "exec:exercises"
  #   "exec:zip"
  # ]

  grunt.registerTask "serve", [
    "build"
    "connect:server"
    "watchImpl"
  ]

  grunt.registerTask "watch", [
    "all"
    "connect:server"
    "watchImpl"
    "serve"
  ]

  grunt.registerTask "default", [
    "all"
  ]