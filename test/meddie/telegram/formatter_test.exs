defmodule Meddie.Telegram.FormatterTest do
  use ExUnit.Case, async: true

  alias Meddie.Telegram.Formatter

  describe "to_telegram_html/1" do
    test "returns empty string for nil" do
      assert Formatter.to_telegram_html(nil) == ""
    end

    test "returns empty string for empty string" do
      assert Formatter.to_telegram_html("") == ""
    end

    test "converts bold text" do
      assert Formatter.to_telegram_html("**bold**") =~ "<strong>bold</strong>"
    end

    test "converts italic text" do
      assert Formatter.to_telegram_html("_italic_") =~ "<em>italic</em>"
    end

    test "converts headers to bold" do
      result = Formatter.to_telegram_html("# Header 1")
      assert result =~ "<b>"
      assert result =~ "Header 1"
      assert result =~ "</b>"
      refute result =~ "<h1>"
    end

    test "converts h2 and h3 to bold" do
      assert Formatter.to_telegram_html("## Header 2") =~ "<b>Header 2</b>"
      assert Formatter.to_telegram_html("### Header 3") =~ "<b>Header 3</b>"
    end

    test "converts unordered lists to bullet text" do
      md = """
      - First item
      - Second item
      - Third item
      """

      result = Formatter.to_telegram_html(md)
      assert result =~ "• First item"
      assert result =~ "• Second item"
      assert result =~ "• Third item"
      refute result =~ "<ul>"
      refute result =~ "<li>"
    end

    test "converts ordered lists to numbered text" do
      md = """
      1. First
      2. Second
      3. Third
      """

      result = Formatter.to_telegram_html(md)
      assert result =~ "1. First"
      assert result =~ "2. Second"
      assert result =~ "3. Third"
      refute result =~ "<ol>"
      refute result =~ "<li>"
    end

    test "preserves inline code" do
      result = Formatter.to_telegram_html("`inline code`")
      assert result =~ "<code>inline code</code>"
      refute result =~ "class="
    end

    test "preserves pre blocks" do
      md = """
      ```
      code block
      ```
      """

      result = Formatter.to_telegram_html(md)
      assert result =~ "<pre>"
      assert result =~ "code block"
    end

    test "preserves links" do
      result = Formatter.to_telegram_html("[click here](https://example.com)")
      assert result =~ "<a"
      assert result =~ "https://example.com"
      assert result =~ "click here"
    end

    test "preserves blockquotes" do
      result = Formatter.to_telegram_html("> quoted text")
      assert result =~ "<blockquote>"
      assert result =~ "quoted text"
    end

    test "strips paragraph tags" do
      result = Formatter.to_telegram_html("Hello world")
      refute result =~ "<p>"
      assert result =~ "Hello world"
    end

    test "handles mixed content like a real AI response" do
      md = """
      ## Analiza wyników

      Ogólnie wyniki wyglądają **solidnie**. Skupię się na tym, co wymaga uwagi.

      ### Wyniki poza normą

      - Cholesterol całkowity — **238 mg/dl** (norma do 190)
      - LDL **156 mg/dl** — podwyższony
      - Amylaza — **147 U/l** (norma do 100)

      Warto rozważyć wizytę u _kardiologa_.
      """

      result = Formatter.to_telegram_html(md)

      # Headers become bold
      assert result =~ "<b>Analiza wyników</b>"
      assert result =~ "<b>Wyniki poza normą</b>"

      # Bold preserved
      assert result =~ "<strong>solidnie</strong>"
      assert result =~ "<strong>238 mg/dl</strong>"

      # List items converted
      assert result =~ "• Cholesterol"
      assert result =~ "• LDL"
      assert result =~ "• Amylaza"

      # Italic preserved
      assert result =~ "<em>kardiologa</em>"

      # No raw HTML tags
      refute result =~ "<h2>"
      refute result =~ "<h3>"
      refute result =~ "<ul>"
      refute result =~ "<li>"
      refute result =~ "<p>"
    end

    test "converts tables with headers to text rows" do
      md = """
      | Marker | Value | Range |
      |--------|-------|-------|
      | Cholesterol | 238 | <190 |
      | LDL | 156 | <115 |
      """

      result = Formatter.to_telegram_html(md)

      # Header row is bold
      assert result =~ "<b>Marker | Value | Range</b>"
      # Data rows are plain
      assert result =~ "Cholesterol | 238 | &lt;190"
      assert result =~ "LDL | 156 | &lt;115"
      # No table tags remain
      refute result =~ "<table>"
      refute result =~ "<tr>"
      refute result =~ "<td>"
      refute result =~ "<th>"
    end

    test "converts simple table without headers" do
      md = """
      | A | B |
      | 1 | 2 |
      """

      result = Formatter.to_telegram_html(md)
      refute result =~ "<table>"
    end

    test "collapses excessive blank lines" do
      md = "First\n\n\n\n\nSecond"
      result = Formatter.to_telegram_html(md)
      refute result =~ "\n\n\n"
    end
  end
end
