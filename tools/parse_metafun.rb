#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

# Copyright (c) 2016 Lifepillar
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

VERSION = '1.0.0'

def debug title, *info
  return unless $DEBUG
  puts "\033[1;35m[DEBUG]\033[1;39m #{title}\033[0m"
  info.each do |chunk|
    chunk.each_line do |l|
      puts "\033[1;35m[DEBUG]\033[0m #{l.chomp!}"
    end
  end
end

def help; <<-HELP
Usage: parse_metafun [<path> ...]
Options:
    -h, --help                       Show this help message and exit.
        --version                    Print version and exit.
        --debug                      Enable debugging.

Example:
    parse_metafun mp-tool.mp mp-step.mp
  HELP
end

# Parse options
paths = []
n = ARGV.length
i = 0
while i < n
  case ARGV[i]
  when /^--version$/
    puts VERSION
    exit(0)
  when /^--debug$/
    $DEBUG = true
  when /^-h|--help$/
    puts help
    exit(0)
  else # Assume it is a path
    paths << ARGV[i]
  end
  i += 1
end

if paths.empty?
  paths << Dir.entries(".")
end

maxlinelen = 52
defs = {}
saved_vars = {}
known_commands = [
]
known_constants = [
]
known_defs = [
]
known_primary_defs = [
]
known_secondary_defs = [
]
known_tertiary_defs = [
]
known_vardefs = [
]
known_num_exps = [
]
known_types = [
]
false_positives = [
  'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', # just to be safe
  'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', # just to be safe
  'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z', # just to be safe
]
types = 'boolean|color|cmykcolor|numeric|pair|path|pen|picture|rgbcolor|string|transform'
types += '|' + known_types.join('|')

begin
  paths.each do |p|
    name = File.basename(p)
    defs[name] = {
      'mpCommand' => [],
      'mpDef' => [],
      'mpVardef' => [],
      'mpPrimaryDef' => [],
      'mpSecondaryDef' => [],
      'mpTertiaryDef' => [],
      'mpNewInternal' => [],
      'mpNumExp' => [],
      'mpType' => [],
      'mpVariable' => [],
      'mpConstant' => [],
      'LET' => []
    }
    saved_vars[name] = []
    File.open(p).each_line do |l|
      next if l =~ /^\s*%/ # skip comments
      /^[^%]*\bdef\s+(\w+)/.match(l) { |m|
        if m[1] !~ /^_|_$/
          defs[name]['mpDef'] << m[1]
        end
      }
      /^[^%]*\bvardef\s+(\w+)/.match(l) { |m|
        if m[1] !~ /^_|_$/
          defs[name]['mpVardef'] << m[1]
        end
      }
      /^[^%]*\bprimarydef\s+\w+\s+(\w+)/.match(l) { |m|
        if m[1] !~ /^_|_$/
          defs[name]['mpPrimaryDef'] << m[1]
        end
      }
      /^[^%]*\bsecondarydef\s+\w+\s+(\w+)/.match(l) { |m|
        if m[1] !~ /^_|_$/
          defs[name]['mpSecondaryDef'] << m[1]
        end
      }
      /^[^%]*\btertiarydef\s+\w+\s+(\w+)/.match(l) { |m|
        if m[1] !~ /^_|_$/
          defs[name]['mpTertiaryDef'] << m[1]
        end
      }
      l.scan(/\bnewinternal\b\s+([^;]+);/).each { |m|
        m[0].split(/,/).each { |w|
          w.strip!
        if w !~ /^_|_$/
            defs[name]['mpNewInternal'] << w
          end
        }
      }
      /^[^%]*\blet\s+(\w+)/.match(l) { |m|
        if m[1] !~ /^_|_$/
          if !false_positives.include?(m[1])
            if known_constants.include?(m[1])
              defs[name]['mpConstant'] << m[1]
            elsif known_types.include?(m[1])
              defs[name]['mpType'] << m[1]
            elsif known_defs.include?(m[1])
              defs[name]['mpDef'] << m[1]
            elsif known_vardefs.include?(m[1])
              defs[name]['mpVardef'] << m[1]
            elsif known_primary_defs.include?(m[1])
              defs[name]['mpPrimaryDef'] << m[1]
            elsif known_secondary_defs.include?(m[1])
              defs[name]['mpSecondaryDef'] << m[1]
            elsif known_tertiary_defs.include?(m[1])
              defs[name]['mpTertiaryDef'] << m[1]
            elsif known_commands.include?(m[1])
              defs[name]['mpCommand'] << m[1]
            elsif known_num_exps.include?(m[1])
              defs[name]['mpNumExp'] << m[1]
            else
              defs[name]['LET'] << m[1]
            end
          end
        end
      }
      l.scan(/\bsave\b\s+([^;]+);/).each do |m| # This considers also save inside comments
        m[0].split(/,/).each do |w|
          saved_vars[name] << w.strip
        end
      end
      l.scan(/\b(#{types})\b\s+([^;]+);/).each { |m|
        m[1].split(/,/).each { |w|
          w.strip!
          w.gsub!(/[\[\]]/, '')
          next unless w =~ /^\w+$/ # Skip if it is not a single token
          next if false_positives.include?(w)
          unless saved_vars.has_key?(name) && saved_vars[name].include?(w)
            if w !~ /^_|_$/
              if known_constants.include?(w)
                defs[name]['mpConstant'] << w
              else
                defs[name]['mpVariable'] << w
              end
            end
          end
        }
      }
    end
  end
  defs.each_key do |n|
    defs[n].each_key do |t|
      defs[n][t].sort!.uniq!
    end
  end
  defs.each_key do |n|
    print "  \" #{n}"
    defs[n].each_pair do |t, l|
      pos = maxlinelen
      l.each do |w|
        if pos + w.length + 1 > maxlinelen
          puts
          print "  syn keyword #{t}"
          print " " * (14 - t.length)
          pos = 0
        end
        print " #{w}"
        pos += w.length + 1
      end
    end
    puts
  end
rescue Interrupt
  puts "parse_metafun interrupted"
  exit(1)
rescue => ex
  puts
  debug 'Backtrace:', ex.backtrace.join("\n")
  "Unexpected exception raised:\n#{ex}"
end

