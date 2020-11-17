# -*- coding: utf-8 -*-
# frozen_string_literal: true

module Rouge
  module Lexers
    class Raku < RegexLexer
      title "Raku"
      desc "The Raku programming language (raku.org)"

      tag 'raku'
      aliases 'perl6'

      filenames '*.raku', '*.rakumod', '*.rakutest', '*.pl6', '*.pm6'
      mimetypes 'text/x-raku', 'application/x-raku', 'text/x-perl6', 'application/x-perl6'

      def self.detect?(text)
        return true if text.shebang? 'raku'
        return true if text.shebang? 'perl6'
        return 0.4  if text.include? 'use v6'
      end

      # See https://github.com/Raku/roast/blob/aa4994a7f6/S02-literals/quoting-unicode.t#L49-L65
      # for the full list
      matching_delimiters = {
        '<' => '>',
        '(' => ')',
        '[' => ']',
        '{' => '}',
        '༺' => '༻',
        '༼' => '༽',
        '᚛' => '᚜',
        '⁅' => '⁆',
        '⁽' => '⁾',
        '₍' => '₎',
        '〈' => '〉',
        '❨' => '❩',
        '❪' => '❫',
        '❬' => '❭',
        '❮' => '❯',
        '❰' => '❱',
        '❲' => '❳',
        '❴' => '❵',
        '⟅' => '⟆',
        '⟦' => '⟧',
        '⟨' => '⟩',
        '⟪' => '⟫',
        '⦃' => '⦄',
        '⦅' => '⦆',
        '⦇' => '⦈',
        '⦉' => '⦊',
        '⦋' => '⦌',
        '⦑' => '⦒',
        '⦓' => '⦔',
        '⦕' => '⦖',
        '⦗' => '⦘',
        '⧘' => '⧙',
        '⧚' => '⧛',
        '⧼' => '⧽',
        '〈' => '〉',
        '《' => '》',
        '「' => '」',
        '『' => '』',
        '【' => '】',
        '〔' => '〕',
        '〖' => '〗',
        '〘' => '〙',
        '〚' => '〛',
        '〝' => '〞',
        '︗' => '︘',
        '︵' => '︶',
        '︷' => '︸',
        '︹' => '︺',
        '︻' => '︼',
        '︽' => '︾',
        '︿' => '﹀',
        '﹁' => '﹂',
        '﹃' => '﹄',
        '﹇' => '﹈',
        '﹙' => '﹚',
        '﹛' => '﹜',
        '﹝' => '﹞',
        '（' => '）',
        '［' => '］',
        '｛' => '｝',
        '｟' => '｠',
        '｢' => '｣',
        '⸨' => '⸩',
      }

      independent_routines = %w(
        EVAL EVALFILE mkdir chdir chmod indir print put say note prompt
        open slurp spurt run shell unpolar printf sprintf flat unique
        repeated squish emit undefine exit done
      )

      phasers = %w(
         BEGIN CHECK INIT END
         ENTER LEAVE KEEP UNDO PRE POST
         FIRST NEXT LAST
         CATCH CONTROL
         COMPOSE
         QUIT CLOSE
         DOC
      )

      low_level_types = %w(
        int int1 int2 int4 int8 int16 int32 int64
        rat rat1 rat2 rat4 rat8 rat16 rat32 rat64
        buf buf1 buf2 buf4 buf8 buf16 buf32 buf64
        uint uint1 uint2 uint4 uint8 uint16 uint32 uint64
        utf8 utf16 utf32 bit bool bag set mix num complex
      )

      start do
        push :expr_start
        @heredoc_queue = []
      end

      state :expr_start do
        rule %r/;/, Punctuation, :pop!
        rule(//) { pop! }
      end

      state :whitespace do
        mixin :inline_whitespace
        rule %r/(;)(\s*)/m do
            groups Text, Text::Whitespace
            push :expr_start
        end

        rule %r/#.*$/, Comment::Single

        rule %r(=begin\b.*?\n=end\b)m, Comment::Multiline
      end

      state :inline_whitespace do
        rule %r/[ \t\r]+/, Text::Whitespace
      end

      state :root do
        mixin :whitespace

        mixin :sigiled_variable
        mixin :delimited_string

        rule %r/\b(?:#{low_level_types.join('|')})\b/, Keyword::Type
        rule %r/\b(?:#{phasers.join('|')})\b/, Keyword
        rule %r/\b(?:#{independent_routines.join('|')})\b/, Name::Function
      end

      state :sigiled_variable do
        rule %r/(?:\$|@|%|&)\p{Alpha}(\p{Alnum}|['-]\p{Alpha})*/i do
          token Name::Variable
          :pop!
        end
      end

      state :delimited_string do
        rule %r/('|"|(?:(q|qq|(Q)(\s*:q\s*)?)([^\w\s])))/ do |m|
          start = Regexp.escape( m[3] || m[2] || m[1] )
          open  = m[5] || m[1]
          close = Regexp.escape(matching_delimiters[open] || open)
          open  = Regexp.escape(open)
          flags = m[4]

          # puts ">>> start: #{start.inspect}"
          # puts ">>> open:  #{open.inspect}"
          # puts ">>> close: #{close.inspect}"
          # puts ">>> flags: #{flags.inspect}"

          token Punctuation

          string_token = Str::Single
          if start == 'qq' || start == '"'
            type = :interpolating
            string_token = Str::Double
          elsif start == 'q' || start == "'" || flags =~ /:q/
            type = :escaping
          else
            type = :literal
          end

          # puts ">>> type: #{type.to_s}"

          push do
            if type == :escaping
              rule %r/\\qq\[/ do
                token Punctuation
                push do
                  mixin :string_interpolation
                  rule %r/\]/, Punctuation, :pop!
                end
              end
            end

            if type != :literal
              uniq_chars = "#{open}#{close}".squeeze
              rule %r/\\[$%&#{uniq_chars}\\]/, Str::Escape
              rule %r/\\/, string_token
            end

            rule %r/#{close}/, Punctuation, :pop!

            if type == :interpolating
              mixin :string_interpolation
            end

            rule %r/[^#{uniq_chars}\\$&%]+/m, string_token
            rule %r/[#{uniq_chars}\\$&%]/, string_token
          end
        end
      end

      state :string_interpolation do
        rule %r/[{]/, Punctuation, :block
        rule %r/[$@%][a-z_-]+(?:\.[a-z_-]+\(\))?/i, Str::Interpol
      end

      state :block do
        rule %r/\}/, Punctuation, :pop!
      end
    end
  end
end
