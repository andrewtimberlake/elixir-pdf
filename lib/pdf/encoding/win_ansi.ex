defmodule Pdf.Encoding.WinAnsi do
  @moduledoc false

  @char_info [
    {0x00, 0x0000, nil},
    {0x01, 0x0001, nil},
    {0x02, 0x0002, nil},
    {0x03, 0x0003, nil},
    {0x04, 0x0004, nil},
    {0x05, 0x0005, nil},
    {0x06, 0x0006, nil},
    {0x07, 0x0007, nil},
    {0x08, 0x0008, nil},
    {0x09, 0x0009, nil},
    {0x0A, 0x000A, nil},
    {0x0B, 0x000B, nil},
    {0x0C, 0x000C, nil},
    {0x0D, 0x000D, nil},
    {0x0E, 0x000E, nil},
    {0x0F, 0x000F, nil},
    {0x10, 0x0010, nil},
    {0x11, 0x0011, nil},
    {0x12, 0x0012, nil},
    {0x13, 0x0013, nil},
    {0x14, 0x0014, nil},
    {0x15, 0x0015, nil},
    {0x16, 0x0016, nil},
    {0x17, 0x0017, nil},
    {0x18, 0x0018, nil},
    {0x19, 0x0019, nil},
    {0x1A, 0x001A, nil},
    {0x1B, 0x001B, nil},
    {0x1C, 0x001C, nil},
    {0x1D, 0x001D, nil},
    {0x1E, 0x001E, nil},
    {0x1F, 0x001F, nil},
    {0x20, 0x0020, :space},
    {0x21, 0x0021, :exclam},
    {0x22, 0x0022, :quotedbl},
    {0x23, 0x0023, :numbersign},
    {0x24, 0x0024, :dollar},
    {0x25, 0x0025, :percent},
    {0x26, 0x0026, :ampersand},
    {0x27, 0x0027, :quotesingle},
    {0x28, 0x0028, :parenleft},
    {0x29, 0x0029, :parenright},
    {0x2A, 0x002A, :asterisk},
    {0x2B, 0x002B, :plus},
    {0x2C, 0x002C, :comma},
    {0x2D, 0x002D, :hyphen},
    {0x2E, 0x002E, :period},
    {0x2F, 0x002F, :slash},
    {0x30, 0x0030, :zero},
    {0x31, 0x0031, :one},
    {0x32, 0x0032, :two},
    {0x33, 0x0033, :three},
    {0x34, 0x0034, :four},
    {0x35, 0x0035, :five},
    {0x36, 0x0036, :six},
    {0x37, 0x0037, :seven},
    {0x38, 0x0038, :eight},
    {0x39, 0x0039, :nine},
    {0x3A, 0x003A, :colon},
    {0x3B, 0x003B, :semicolon},
    {0x3C, 0x003C, :less},
    {0x3D, 0x003D, :equal},
    {0x3E, 0x003E, :greater},
    {0x3F, 0x003F, :question},
    {0x40, 0x0040, :at},
    {0x41, 0x0041, :A},
    {0x42, 0x0042, :B},
    {0x43, 0x0043, :C},
    {0x44, 0x0044, :D},
    {0x45, 0x0045, :E},
    {0x46, 0x0046, :F},
    {0x47, 0x0047, :G},
    {0x48, 0x0048, :H},
    {0x49, 0x0049, :I},
    {0x4A, 0x004A, :J},
    {0x4B, 0x004B, :K},
    {0x4C, 0x004C, :L},
    {0x4D, 0x004D, :M},
    {0x4E, 0x004E, :N},
    {0x4F, 0x004F, :O},
    {0x50, 0x0050, :P},
    {0x51, 0x0051, :Q},
    {0x52, 0x0052, :R},
    {0x53, 0x0053, :S},
    {0x54, 0x0054, :T},
    {0x55, 0x0055, :U},
    {0x56, 0x0056, :V},
    {0x57, 0x0057, :W},
    {0x58, 0x0058, :X},
    {0x59, 0x0059, :Y},
    {0x5A, 0x005A, :Z},
    {0x5B, 0x005B, :bracketleft},
    {0x5C, 0x005C, :backslash},
    {0x5D, 0x005D, :bracketright},
    {0x5E, 0x005E, :asciicircum},
    {0x5F, 0x005F, :underscore},
    {0x60, 0x0060, :grave},
    {0x61, 0x0061, :a},
    {0x62, 0x0062, :b},
    {0x63, 0x0063, :c},
    {0x64, 0x0064, :d},
    {0x65, 0x0065, :e},
    {0x66, 0x0066, :f},
    {0x67, 0x0067, :g},
    {0x68, 0x0068, :h},
    {0x69, 0x0069, :i},
    {0x6A, 0x006A, :j},
    {0x6B, 0x006B, :k},
    {0x6C, 0x006C, :l},
    {0x6D, 0x006D, :m},
    {0x6E, 0x006E, :n},
    {0x6F, 0x006F, :o},
    {0x70, 0x0070, :p},
    {0x71, 0x0071, :q},
    {0x72, 0x0072, :r},
    {0x73, 0x0073, :s},
    {0x74, 0x0074, :t},
    {0x75, 0x0075, :u},
    {0x76, 0x0076, :v},
    {0x77, 0x0077, :w},
    {0x78, 0x0078, :x},
    {0x79, 0x0079, :y},
    {0x7A, 0x007A, :z},
    {0x7B, 0x007B, :braceleft},
    {0x7C, 0x007C, :bar},
    {0x7D, 0x007D, :braceright},
    {0x7E, 0x007E, :asciitilde},
    {0x7F, 0x007F, nil},
    {0x80, 0x20AC, :Euro},
    {0x81, nil, nil},
    {0x82, 0x201A, :quotesinglbase},
    {0x83, 0x0192, :florin},
    {0x84, 0x201E, :quotedblbase},
    {0x85, 0x2026, :ellipsis},
    {0x86, 0x2020, :dagger},
    {0x87, 0x2021, :daggerdbl},
    {0x88, 0x02C6, :circumflex},
    {0x89, 0x2030, :perthousand},
    {0x8A, 0x0160, :Scaron},
    {0x8B, 0x2039, :guilsinglleft},
    {0x8C, 0x0152, :OE},
    {0x8D, nil, nil},
    {0x8E, 0x017D, :Zcaron},
    {0x8F, nil, nil},
    {0x90, nil, nil},
    {0x91, 0x2018, :quoteleft},
    {0x92, 0x2019, :quoteright},
    {0x93, 0x201C, :quotedblleft},
    {0x94, 0x201D, :quotedblright},
    {0x95, 0x2022, :bullet},
    {0x96, 0x2013, :endash},
    {0x97, 0x2014, :emdash},
    {0x98, 0x02DC, :tilde},
    {0x99, 0x2122, :trademark},
    {0x9A, 0x0161, :scaron},
    {0x9B, 0x203A, :guilsinglright},
    {0x9C, 0x0153, :oe},
    {0x9D, nil, nil},
    {0x9E, 0x017E, :zcaron},
    {0x9F, 0x0178, :Ydieresis},
    {0xA0, 0x00A0, :space},
    {0xA1, 0x00A1, :exclamdown},
    {0xA2, 0x00A2, :cent},
    {0xA3, 0x00A3, :sterling},
    {0xA4, 0x00A4, :currency},
    {0xA5, 0x00A5, :yen},
    {0xA6, 0x00A6, :brokenbar},
    {0xA7, 0x00A7, :section},
    {0xA8, 0x00A8, :dieresis},
    {0xA9, 0x00A9, :copyright},
    {0xAA, 0x00AA, :ordfeminine},
    {0xAB, 0x00AB, :guillemotleft},
    {0xAC, 0x00AC, :logicalnot},
    {0xAD, 0x00AD, :hyphen},
    {0xAE, 0x00AE, :registered},
    {0xAF, 0x00AF, :macron},
    {0xB0, 0x00B0, :degree},
    {0xB1, 0x00B1, :plusminus},
    {0xB2, 0x00B2, :twosuperior},
    {0xB3, 0x00B3, :threesuperior},
    {0xB4, 0x00B4, :acute},
    {0xB5, 0x00B5, :mu},
    {0xB6, 0x00B6, :paragraph},
    {0xB7, 0x00B7, :periodcentered},
    {0xB8, 0x00B8, :cedilla},
    {0xB9, 0x00B9, :onesuperior},
    {0xBA, 0x00BA, :ordmasculine},
    {0xBB, 0x00BB, :guillemotright},
    {0xBC, 0x00BC, :onequarter},
    {0xBD, 0x00BD, :onehalf},
    {0xBE, 0x00BE, :threequarters},
    {0xBF, 0x00BF, :questiondown},
    {0xC0, 0x00C0, :Agrave},
    {0xC1, 0x00C1, :Aacute},
    {0xC2, 0x00C2, :Acircumflex},
    {0xC3, 0x00C3, :Atilde},
    {0xC4, 0x00C4, :Adieresis},
    {0xC5, 0x00C5, :Aring},
    {0xC6, 0x00C6, :AE},
    {0xC7, 0x00C7, :Ccedilla},
    {0xC8, 0x00C8, :Egrave},
    {0xC9, 0x00C9, :Eacute},
    {0xCA, 0x00CA, :Ecircumflex},
    {0xCB, 0x00CB, :Edieresis},
    {0xCC, 0x00CC, :Igrave},
    {0xCD, 0x00CD, :Iacute},
    {0xCE, 0x00CE, :Icircumflex},
    {0xCF, 0x00CF, :Idieresis},
    {0xD0, 0x00D0, :Eth},
    {0xD1, 0x00D1, :Ntilde},
    {0xD2, 0x00D2, :Ograve},
    {0xD3, 0x00D3, :Oacute},
    {0xD4, 0x00D4, :Ocircumflex},
    {0xD5, 0x00D5, :Otilde},
    {0xD6, 0x00D6, :Odieresis},
    {0xD7, 0x00D7, :multiply},
    {0xD8, 0x00D8, :Oslash},
    {0xD9, 0x00D9, :Ugrave},
    {0xDA, 0x00DA, :Uacute},
    {0xDB, 0x00DB, :Ucircumflex},
    {0xDC, 0x00DC, :Udieresis},
    {0xDD, 0x00DD, :Yacute},
    {0xDE, 0x00DE, :Thorn},
    {0xDF, 0x00DF, :germandbls},
    {0xE0, 0x00E0, :agrave},
    {0xE1, 0x00E1, :aacute},
    {0xE2, 0x00E2, :acircumflex},
    {0xE3, 0x00E3, :atilde},
    {0xE4, 0x00E4, :adieresis},
    {0xE5, 0x00E5, :aring},
    {0xE6, 0x00E6, :ae},
    {0xE7, 0x00E7, :ccedilla},
    {0xE8, 0x00E8, :egrave},
    {0xE9, 0x00E9, :eacute},
    {0xEA, 0x00EA, :ecircumflex},
    {0xEB, 0x00EB, :edieresis},
    {0xEC, 0x00EC, :igrave},
    {0xED, 0x00ED, :iacute},
    {0xEE, 0x00EE, :icircumflex},
    {0xEF, 0x00EF, :idieresis},
    {0xF0, 0x00F0, :eth},
    {0xF1, 0x00F1, :ntilde},
    {0xF2, 0x00F2, :ograve},
    {0xF3, 0x00F3, :oacute},
    {0xF4, 0x00F4, :ocircumflex},
    {0xF5, 0x00F5, :otilde},
    {0xF6, 0x00F6, :odieresis},
    {0xF7, 0x00F7, :divide},
    {0xF8, 0x00F8, :oslash},
    {0xF9, 0x00F9, :ugrave},
    {0xFA, 0x00FA, :uacute},
    {0xFB, 0x00FB, :ucircumflex},
    {0xFC, 0x00FC, :udieresis},
    {0xFD, 0x00FD, :yacute},
    {0xFE, 0x00FE, :thorn},
    {0xFF, 0x00FF, :ydieresis},
    {0x200B, 0x200B, :zero_width_space}
  ]

  @char_info
  |> Enum.uniq_by(&elem(&1, 2))
  |> Enum.each(fn
    {_, _, nil} ->
      nil

    {char_code, _utf_code, name} ->
      def from_name(unquote(to_string(name))), do: unquote(char_code)
  end)

  def from_name(_), do: nil

  def characters do
    Enum.map(Enum.take(@char_info, 256), fn {c, u, name} -> {c, u, to_string(name)} end)
  end

  def encode(""), do: ""

  @char_info
  |> Enum.each(fn
    {char, nil, _} ->
      def encode(<<unquote(char)::utf8, rest::binary>>),
        do: <<unquote(char)::utf8>> <> encode(rest)

    {char, utf_char, _} ->
      def encode(<<unquote(char)::utf8, rest::binary>>),
        do: <<unquote(char)::utf8>> <> encode(rest)

      if <<char::utf8>> != <<utf_char::utf8>> do
        def encode(<<unquote(utf_char)::utf8, rest::binary>>),
          do: <<unquote(char)::utf8>> <> encode(rest)
      end
  end)

  def encode(_), do: raise(ArgumentError, "Incompatible with WinAnsi encoding")
end
