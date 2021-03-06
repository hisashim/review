# encoding: utf-8
#
# Copyright (c) 2002-2007 Minero Aoki
#               2008-2009 Minero Aoki, Kenshi Muto
#               2010-2016  Minero Aoki, Kenshi Muto, TAKAHASHI Masayoshi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
# For details of the GNU LGPL, see the file "COPYING".
#

require 'review/builder'
require 'review/latexutils'
require 'review/textutils'

module ReVIEW

  class LATEXBuilder < Builder

    include LaTeXUtils
    include TextUtils

    [:dtp, :hd_chap].each {|e|
      Compiler.definline(e)
    }

    Compiler.defsingle(:latextsize, 1)

    def extname
      '.tex'
    end

    def builder_init_file
      @blank_needed = false
      @latex_tsize = nil
      @tsize = nil
      @table_caption = nil
      @ol_num = nil
      @first_line_num = nil
      @sec_counter = SecCounter.new(5, @chapter)
      initialize_metachars(@book.config["texcommand"])
    end
    private :builder_init_file

    def blank
      @blank_needed = true
    end
    private :blank

    def print(*s)
      if @blank_needed
        @output.puts
        @blank_needed = false
      end
      super
    end
    private :print

    def puts(*s)
      if @blank_needed
        @output.puts
        @blank_needed = false
      end
      super
    end
    private :puts

    HEADLINE = {
      1 => 'chapter',
      2 => 'section',
      3 => 'subsection',
      4 => 'subsubsection',
      5 => 'paragraph',
      6 => 'subparagraph'
    }

    def headline(level, label, caption)
      def compile_inline_runhead(s)
        s_cleansed = s
          .gsub(/@<fn>\{[^}]*?\}/, '')
          .gsub(/@<\w+?>\{([^}]*?)\}/){$1}
        compile_inline(s_cleansed)
      end
      _, anchor = headline_prefix(level)
      headline_name = HEADLINE[level]
      if @chapter.kind_of? ReVIEW::Book::Part
        headline_name = "part"
      end
      prefix = ""
      if level > @book.config["secnolevel"] || (@chapter.number.to_s.empty? && level > 1)
        prefix = "*"
      else
        prefix = "[#{compile_inline_runhead(caption)}]"
      end
      blank unless @output.pos == 0
      puts macro(headline_name+prefix, compile_inline(caption))
      if prefix == "*" && level <= @book.config["toclevel"].to_i
        puts "\\addcontentsline{toc}{#{headline_name}}{#{compile_inline_runhead(caption)}}"
      end
      if level == 1
        puts macro('label', chapter_label)
      else
        puts macro('label', sec_label(anchor))
      end
    rescue => e
      error "unknown level: #{level} (#{e.inspect})"
    end

    def nonum_begin(level, label, caption)
      blank unless @output.pos == 0
      puts macro(HEADLINE[level]+"*", compile_inline(caption))
      puts macro('addcontentsline', 'toc', HEADLINE[level], compile_inline(caption))
    end

    def nonum_end(level)
    end

    def notoc_begin(level, label, caption)
      blank unless @output.pos == 0
      puts macro(HEADLINE[level]+"*", compile_inline(caption))
    end

    def notoc_end(level)
    end

    def nodisp_begin(level, label, caption)
      blank unless @output.pos == 0
      puts macro('clearpage') if @output.pos == 0
      puts macro('addcontentsline', 'toc', HEADLINE[level], compile_inline(caption))
      # FIXME: headings
    end

    def nodisp_end(level)
    end

    def column_begin(level, label, caption)
      blank
      puts "\\begin{reviewcolumn}\n"
      if label
        puts "\\hypertarget{#{column_label(label)}}{}"
      else
        puts "\\hypertarget{#{column_label(caption)}}{}"
      end
      puts macro('reviewcolumnhead', nil, compile_inline(caption))
      if level <= @book.config["toclevel"].to_i
        puts "\\addcontentsline{toc}{#{HEADLINE[level]}}{#{compile_inline(caption)}}"
      end
    end

    def column_end(level)
      puts "\\end{reviewcolumn}\n"
      blank
    end

    def captionblock(type, lines, caption)
      puts "\\begin{reviewminicolumn}\n"
      unless caption.nil?
        puts "\\reviewminicolumntitle{#{compile_inline(caption)}}\n"
      end

      blocked_lines = split_paragraph(lines)
      puts blocked_lines.join("\n\n")

      puts "\\end{reviewminicolumn}\n"
    end

    def box(lines, caption = nil)
      blank
      if caption
        puts macro('reviewboxcaption', "#{compile_inline(caption)}")
      end
      puts '\begin{reviewbox}'
      lines.each do |line|
        puts detab(line)
      end
      puts '\end{reviewbox}'
      blank
    end

    def ul_begin
      blank
      puts '\begin{itemize}'
    end

    def ul_item(lines)
      str = lines.join
      str.sub!(/\A(\[)/){'\lbrack{}'}
      puts '\item ' + str
    end

    def ul_end
      puts '\end{itemize}'
      blank
    end

    def ol_begin
      blank
      puts '\begin{enumerate}'
      if @ol_num
        puts "\\setcounter{enumi}{#{@ol_num - 1}}"
        @ol_num = nil
      end
    end

    def ol_item(lines, num)
      str = lines.join
      str.sub!(/\A(\[)/){'\lbrack{}'}
      puts '\item ' + str
    end

    def ol_end
      puts '\end{enumerate}'
      blank
    end

    def dl_begin
      blank
      puts '\begin{description}'
    end

    def dt(str)
      str.sub!(/\[/){'\lbrack{}'}
      str.sub!(/\]/){'\rbrack{}'}
      puts '\item[' + str + '] \mbox{} \\\\'
    end

    def dd(lines)
      puts lines.join
    end

    def dl_end
      puts '\end{description}'
      blank
    end

    def paragraph(lines)
      blank
      lines.each do |line|
        puts line
      end
      blank
    end

    def parasep
      puts '\\parasep'
    end

    def read(lines)
      latex_block 'quotation', lines
    end

    alias_method :lead, :read

    def highlight_listings?
      @book.config["highlight"] && @book.config["highlight"]["latex"] == "listings"
    end
    private :highlight_listings?

    def emlist(lines, caption = nil, lang = nil)
      blank
      if highlight_listings?
        common_code_block_lst(nil, lines, 'reviewemlistlst', 'title', caption, lang)
      else
        common_code_block(nil, lines, 'reviewemlist', caption, lang) do |line, idx|
          detab(line) + "\n"
        end
      end
    end

    def emlistnum(lines, caption = nil, lang = nil)
      blank
      first_line_num = get_line_num
      if highlight_listings?
        common_code_block_lst(nil, lines, 'reviewemlistnumlst', 'title', caption, lang, first_line_num: first_line_num)
      else
        common_code_block(nil, lines, 'reviewemlist', caption, lang) do |line, idx|
          detab((idx+first_line_num).to_s.rjust(2)+": " + line) + "\n"
        end
      end
    end

    ## override Builder#list
    def list(lines, id, caption, lang = nil)
      if highlight_listings?
        common_code_block_lst(id, lines, 'reviewlistlst', 'caption', caption, lang)
      else
        common_code_block(id, lines, 'reviewlist', caption, lang) do |line, idx|
          detab(line) + "\n"
        end
      end
    end

    ## override Builder#listnum
    def listnum(lines, id, caption, lang = nil)
      first_line_num = get_line_num
      if highlight_listings?
        common_code_block_lst(id, lines, 'reviewlistnumlst', 'caption', caption, lang, first_line_num: first_line_num)
      else
        common_code_block(id, lines, 'reviewlist', caption, lang) do |line, idx|
          detab((idx+first_line_num).to_s.rjust(2)+": " + line) + "\n"
        end
      end
    end

    def cmd(lines, caption = nil, lang = nil)
      if highlight_listings?
        common_code_block_lst(nil, lines, 'reviewcmdlst', 'title', caption, lang)
      else
        blank
        common_code_block(nil, lines, 'reviewcmd', caption, lang) do |line, idx|
          detab(line) + "\n"
        end
      end
    end

    def common_code_block(id, lines, command, caption, lang)
      if caption
        if command =~ /emlist/ || command =~ /cmd/ || command =~ /source/
          puts macro(command + 'caption', "#{compile_inline(caption)}")
        else
          begin
            puts macro('reviewlistcaption', "#{I18n.t("list")}#{I18n.t("format_number_header", [@chapter.number, @chapter.list(id).number])}#{I18n.t("caption_prefix")}#{compile_inline(caption)}")
          rescue KeyError
            error "no such list: #{id}"
          end
        end
      end
      body = ""
      lines.each_with_index do |line, idx|
        body.concat(yield(line, idx))
      end
      puts macro('begin' ,command)
      print body
      puts macro('end' ,command)
      blank
    end

    def common_code_block_lst(id, lines, command, title, caption, lang, first_line_num: 1)
      if title == "title" && caption.blank?
        print "\\vspace{-1.5em}"
      end
      body = lines.inject(''){|i, j| i + detab(unescape_latex(j)) + "\n"}
      args = make_code_block_args(title, caption, lang, first_line_num: first_line_num)
      puts "\\begin{"+command+"}[" + args + "]"
      print body
      puts "\\end{"+ command + "}"
      blank
    end

    def make_code_block_args(title, caption, lang, first_line_num: 1)
      caption_str = compile_inline((caption || ""))
      if title == "title" && caption_str == ""
        caption_str = "\\relax" ## dummy charactor to remove lstname
      end
      if @book.config["highlight"] && @book.config["highlight"]["lang"]
        lexer = @book.config["highlight"]["lang"] # default setting
      else
        lexer = ""
      end
      lexer = lang if lang.present?
      args = title + "={" + caption_str + "},language={" + lexer + "}"
      if first_line_num != 1
        args += ",firstnumber=#{first_line_num}"
      end
      args
    end

    def source(lines, caption, lang = nil)
      if highlight_listings?
        common_code_block_lst(nil, lines, 'reviewsourcelst', 'title', caption, lang)
      else
        common_code_block(nil, lines, 'reviewsource', caption, lang) do |line, idx|
          detab(line) + "\n"
        end
      end
    end


    def image_header(id, caption)
    end

    def handle_metric(str)
      if @book.config["image_scale2width"] && str =~ /\Ascale=([\d.]+)\Z/
        return "width=#{$1}\\maxwidth"
      end
      str
    end

    def result_metric(array)
      "#{array.join(',')}"
    end

    def image_image(id, caption, metric)
      metrics = parse_metric("latex", metric)
      # image is always bound here
      puts '\begin{reviewimage}'
      if metrics.present?
        puts "\\includegraphics[#{metrics}]{#{@chapter.image(id).path}}"
      else
        puts "\\includegraphics[width=\\maxwidth]{#{@chapter.image(id).path}}"
      end
      if caption.present?
        puts macro('caption', compile_inline(caption))
      end
      puts macro('label', image_label(id))
      puts '\end{reviewimage}'
    end

    def image_dummy(id, caption, lines)
      puts '\begin{reviewdummyimage}'
      path = @chapter.image(id).path
      puts "--[[path = #{path} (#{existence(id)})]]--"
      lines.each do |line|
        puts detab(line.rstrip)
      end
      puts macro('label', image_label(id))
      puts compile_inline(caption)
      puts '\end{reviewdummyimage}'
    end

    def existence(id)
      @chapter.image(id).bound? ? 'exist' : 'not exist'
    end
    private :existence

    def image_label(id, chapter=nil)
      chapter ||= @chapter
      "image:#{chapter.id}:#{id}"
    end
    private :image_label

    def chapter_label
      "chap:#{@chapter.id}"
    end
    private :chapter_label

    def sec_label(sec_anchor)
      "sec:#{sec_anchor}"
    end
    private :sec_label

    def table_label(id, chapter=nil)
      chapter ||= @chapter
      "table:#{chapter.id}:#{id}"
    end
    private :table_label

    def bib_label(id)
      "bib:#{id}"
    end
    private :bib_label

    def column_label(id)
      filename = @chapter.id
      num = @chapter.column(id).number
      "column:#{filename}:#{num}"
    end
    private :column_label

    def indepimage(id, caption=nil, metric=nil)
      metrics = parse_metric("latex", metric)
      puts '\begin{reviewimage}'
      if metrics.present?
        puts "\\includegraphics[#{metrics}]{#{@chapter.image(id).path}}"
      else
        puts "\\includegraphics[width=\\maxwidth]{#{@chapter.image(id).path}}"
      end
      if caption.present?
        puts macro('reviewindepimagecaption',
                   %Q[#{I18n.t("numberless_image")}#{I18n.t("caption_prefix")}#{compile_inline(caption)}])
      end
      puts '\end{reviewimage}'
    end

    alias_method :numberlessimage, :indepimage

    def table(lines, id = nil, caption = nil)
      rows = []
      sepidx = nil
      lines.each_with_index do |line, idx|
        if /\A[\=\{\-\}]{12}/ =~ line
          # just ignore
          #error "too many table separator" if sepidx
          sepidx ||= idx
          next
        end
        rows.push line.strip.split(/\t+/).map {|s| s.sub(/\A\./, '') }
      end
      rows = adjust_n_cols(rows)

      begin
        table_header id, caption unless caption.nil?
      rescue KeyError
        error "no such table: #{id}"
      end
      return if rows.empty?
      table_begin rows.first.size
      if sepidx
        sepidx.times do
          tr rows.shift.map {|s| th(s) }
        end
        rows.each do |cols|
          tr cols.map {|s| td(s) }
        end
      else
        rows.each do |cols|
          h, *cs = *cols
          tr [th(h)] + cs.map {|s| td(s) }
        end
      end
      table_end
    end

    def table_header(id, caption)
      if caption.present?
        @table_caption = true
        puts '\begin{table}[h]'
        puts macro('reviewtablecaption', compile_inline(caption))
      end
      puts macro('label', table_label(id))
    end

    def table_begin(ncols)
      if @latex_tsize
        puts macro('begin', 'reviewtable', @latex_tsize)
      elsif @tsize
        cellwidth = @tsize.split(/\s*,\s*/)
        puts macro('begin', 'reviewtable', '|'+cellwidth.collect{|i| "p{#{i}mm}"}.join('|')+'|')
      else
        puts macro('begin', 'reviewtable', (['|'] * (ncols + 1)).join('l'))
      end
      puts '\hline'
      @tsize = nil
      @latex_tsize = nil
    end

    def table_separator
      #puts '\hline'
    end

    def th(s)
      ## use shortstack for @<br>
      if /\\\\/i =~ s
        macro('reviewth', macro('shortstack[l]', s))
      else
        macro('reviewth', s)
      end
    end

    def td(s)
      ## use shortstack for @<br>
      if /\\\\/ =~ s
        macro('shortstack[l]', s)
      else
        s
      end
    end

    def tr(rows)
      print rows.join(' & ')
      puts ' \\\\  \hline'
    end

    def table_end
      puts macro('end', 'reviewtable')
      if @table_caption
        puts '\end{table}'
      end
      @table_caption = nil
      blank
    end

    def imgtable(lines, id, caption = nil, metric = nil)
      if !@chapter.image(id).bound?
        warn "image not bound: #{id}"
        image_dummy id, caption, lines
        return
      end

      begin
        if caption.present?
          @table_caption = true
          puts '\begin{table}[h]'
          puts macro('reviewimgtablecaption', compile_inline(caption))
        end
        puts macro('label', table_label(id))
      rescue ReVIEW::KeyError
        error "no such table: #{id}"
      end
      imgtable_image(id, caption, metric)

      puts '\end{table}' if @table_caption
      @table_caption = nil
      blank
    end

    def imgtable_image(id, caption, metric)
      metrics = parse_metric("latex", metric)
      # image is always bound here
      puts '\begin{reviewimage}'
      if metrics.present?
        puts "\\includegraphics[#{metrics}]{#{@chapter.image(id).path}}"
      else
        puts "\\includegraphics[width=\\maxwidth]{#{@chapter.image(id).path}}"
      end
      puts '\end{reviewimage}'
    end

    def quote(lines)
      latex_block 'quote', lines
    end

    def center(lines)
      latex_block 'center', lines
    end

    alias_method :centering, :center

    def flushright(lines)
      latex_block 'flushright', lines
    end

    def texequation(lines)
      blank
      puts macro('begin','equation*')
      lines.each do |line|
        puts unescape_latex(line)
      end
      puts macro('end', 'equation*')
      blank
    end

    def latex_block(type, lines)
      blank
      puts macro('begin', type)
      blocked_lines = split_paragraph(lines)
      puts blocked_lines.join("\n\n")
      puts macro('end', type)
      blank
    end
    private :latex_block

    def direct(lines, fmt)
      return unless fmt == 'latex'
      lines.each do |line|
        puts line
      end
    end

    def comment(lines, comment = nil)
      lines ||= []
      lines.unshift comment unless comment.blank?
      if @book.config["draft"]
        str = lines.join("")
        puts macro('pdfcomment', escape(str))
      end
    end

    def hr
      puts '\hrule'
    end

    def label(id)
      puts macro('label', id)
    end

    def pagebreak
      puts '\pagebreak'
    end

    def linebreak
      puts '\\\\'
    end

    def noindent
      print '\noindent'
    end

    def inline_chapref(id)
      title = super
      if @book.config["chapterlink"]
        "\\hyperref[chap:#{id}]{#{title}}"
      else
        title
      end
    rescue KeyError
      error "unknown chapter: #{id}"
      nofunc_text("[UnknownChapter:#{id}]")
    end

    def inline_chap(id)
      if @book.config["chapterlink"]
        "\\hyperref[chap:#{id}]{#{@book.chapter_index.number(id)}}"
      else
        @book.chapter_index.number(id)
      end
    rescue KeyError
      error "unknown chapter: #{id}"
      nofunc_text("[UnknownChapter:#{id}]")
    end

    def inline_title(id)
      title = super
      if @book.config["chapterlink"]
        "\\hyperref[chap:#{id}]{#{title}}"
      else
        title
      end
    rescue KeyError
      error "unknown chapter: #{id}"
      nofunc_text("[UnknownChapter:#{id}]")
    end


    # FIXME: use TeX native label/ref.
    def inline_list(id)
      chapter, id = extract_chapter_id(id)
      macro('reviewlistref', "#{chapter.number}.#{chapter.list(id).number}")
    end

    def inline_table(id)
      chapter, id = extract_chapter_id(id)
      macro('reviewtableref', "#{chapter.number}.#{chapter.table(id).number}", table_label(id, chapter))
    end

    def inline_img(id)
      chapter, id = extract_chapter_id(id)
      macro('reviewimageref', "#{chapter.number}.#{chapter.image(id).number}", image_label(id, chapter))
    end

    def footnote(id, content)
      if @book.config["footnotetext"]
        puts macro("footnotetext[#{@chapter.footnote(id).number}]",
                   compile_inline(content.strip))
      end
    end

    def inline_fn(id)
      if @book.config["footnotetext"]
        macro("footnotemark[#{@chapter.footnote(id).number}]", "")
      else
        macro('footnote', compile_inline(@chapter.footnote(id).content.strip))
      end
    end

    BOUTEN = "・"

    def inline_bou(str)
      str.split(//).map {|c| macro('ruby', escape(c), macro('textgt', BOUTEN)) }.join('\allowbreak')
    end

    def compile_ruby(base, ruby)
      macro('ruby', escape(base), escape(ruby))
    end

    # math
    def inline_m(str)
      " $#{str}$ "
    end

    # hidden index
    def inline_hi(str)
      index(str)
    end

    # index -> italic
    def inline_i(str)
      macro('textit', escape(str))
    end

    # index
    def inline_idx(str)
      escape(str) + index(str)
    end

    # hidden index??
    def inline_hidx(str)
      index(str)
    end

    # bold
    def inline_b(str)
      macro('textbf', escape(str))
    end

    # line break
    def inline_br(str)
      "\\\\\n"
    end

    def inline_dtp(str)
      # ignore
      ""
    end

    ## @<code> is same as @<tt>
    def inline_code(str)
      macro('texttt', escape(str))
    end

    def nofunc_text(str)
      escape(str)
    end

    def inline_tt(str)
      macro('texttt', escape(str))
    end

    def inline_del(str)
      macro('reviewstrike', escape(str))
    end

    def inline_tti(str)
      macro('texttt', macro('textit', escape(str)))
    end

    def inline_ttb(str)
      macro('texttt', macro('textbf', escape(str)))
    end

    def inline_bib(id)
      macro('reviewbibref', "[#{@chapter.bibpaper(id).number}]", bib_label(id))
    end

    def inline_hd_chap(chap, id)
      n = chap.headline_index.number(id)
      if chap.number and @book.config["secnolevel"] >= n.split('.').size
        str = I18n.t("chapter_quote", "#{chap.headline_index.number(id)} #{compile_inline(chap.headline(id).caption)}")
      else
        str = I18n.t("chapter_quote", compile_inline(chap.headline(id).caption))
      end
      if @book.config["chapterlink"]
        anchor = n.gsub(/\./, "-")
        macro('reviewsecref', str, sec_label(anchor))
      else
        str
      end
    end

    def inline_column_chap(chapter, id)
      macro('reviewcolumnref',
        I18n.t("chapter_quote", compile_inline(chapter.column(id).caption)),
        column_label(id))
    end

    def inline_raw(str)
      super(str)
    end

    def inline_sub(str)
      macro('textsubscript', escape(str))
    end

    def inline_sup(str)
      macro('textsuperscript', escape(str))
    end

    def inline_em(str)
      macro('reviewem', escape(str))
    end

    def inline_strong(str)
      macro('reviewstrong', escape(str))
    end

    def inline_u(str)
      macro('reviewunderline', escape(str))
    end

    def inline_ami(str)
      macro('reviewami', escape(str))
    end

    def inline_icon(id)
      macro('includegraphics', @chapter.image(id).path)
    end

    def inline_uchar(str)
      # with otf package
      macro('UTF', escape(str))
    end

    def inline_comment(str)
      if @book.config["draft"]
        macro('pdfcomment', escape(str))
      else
        ""
      end
    end

    def inline_tcy(str)
      macro('rensuji', escape(str))
    end

    def bibpaper_header(id, caption)
      puts "[#{@chapter.bibpaper(id).number}] #{compile_inline(caption)}"
      puts macro('label', bib_label(id))
    end

    def bibpaper_bibpaper(id, caption, lines)
      print split_paragraph(lines).join("")
      puts ""
    end

    def index(str)
      str.sub!(/\(\)/, '')
      decl = ''
      if /@\z/ =~ str
        str.chop!
        decl = '|IndexDecl'
      end
      unless /[^ -~]/ =~ str
        if /\^/ =~ str
          macro('index', escape_index(str.gsub(/\^/, '')) + '@' + escape_index(text(str)) + decl)
        else
          '\index{' + escape_index(text(str)) + decl + '}'
        end
      else
        '\index{' + escape_index(@index_db[str]) + '@' + escape_index(text(str)) + '}'
      end
    end

    def compile_kw(word, alt)
      if alt
        macro('reviewkw', escape(word)) + "（#{escape(alt.strip)}）"
      else
        macro('reviewkw', escape(word))
      end
    end

    def compile_href(url, label)
      if /\A[a-z]+:/ =~ url
        if label
          macro("href", escape_url(url), escape(label))
        else
          macro("url", escape_url(url))
        end
      else
        macro("ref", url)
      end
    end

    def tsize(str)
      @tsize = str
    end

    def latextsize(str)
      @latex_tsize = str
    end

    def image_ext
      "pdf"
    end

    def olnum(num)
      @ol_num = num.to_i
    end

  end

end
