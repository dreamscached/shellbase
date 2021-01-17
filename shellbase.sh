#!/usr/bin/env bash
function word_pos() {
    # $1: string; $2: index; $3: search direction (0 - to the left, 1 - to the right)

    if [[ "$3" -eq 0 ]]; then # Look to the left
        for ((i = "$(($2 - 1))"; i > 0; i--)); do
            if ! grep -q "\w" <<< "${1:$((i - 1)):1}"; then
                echo "$i"
                return 0
            fi
        done
    elif [[ "$3" -eq 1 ]]; then # Look to the right
        for ((i = "$(($2 + 1))"; i < "${#1}"; i++)); do
            if ! grep -q "\w" <<< "${1:$i:1}"; then
                echo "$i"
                return 0
            fi
        done
    fi
    return 1
}

function prompt_loop() {
    local buf mod input cur_pos new_cur_pos hist_pos

    while :; do
        unset input buf cur_pos new_cur_pos hist_pos

        while :; do
            unset mod

            printf -- "\r\033[K(shellbase) %s" "$input"
            printf -- "\r(shellbase) %s" "${input:0:$cur_pos}"

            stty -echo

            IFS= read -r -n 1 buf
            if [[ -z "$buf" ]]; then # Enter
                echo
                history+=("$input")
                break
            elif [[ "$buf" == $'\177' ]]; then # Backspace
                if [[ "${cur_pos-:0}" -gt 0 ]]; then
                    input="${input:0:$((cur_pos - 1))}${input:$cur_pos}"
                    cur_pos="$((cur_pos - 1))"
                fi
            elif [[ "$buf" == $'\004' ]]; then # Ctrl+D
                return
            elif [[ "$buf" == $'\E' ]]; then # Escape sequence
                read -r -n 1 buf
                case "$buf" in
                    "[") read -r -n 1 buf
                         case "$buf" in
                             "1") read -r -n 1 buf
                                  if [[ "$buf" == ";" ]]; then
                                      read -r -n 1 buf
                                      case "$buf" in # Modifier key sequence
                                          "5") mod=("ctrl");;
                                          "3") mod=("alt");;
                                          "7") mod=("ctrl" "alt");;
                                      esac
                                      read -r -n 1 buf
                                  fi;;
                         esac
                         case "$buf" in
                             "2") read -r -n 1;;
                             "3") read -r -n 1; input="${input:0:$cur_pos}${input:$((cur_pos + 1))}";; # Delete
                             "5") read -r -n 1 buf # Page Up
                                  case "$buf" in
                                      "~") hist_pos="$((${#history[@]} - 1))"
                                           input="${history[$hist_pos]}"
                                           cur_pos="${#input}";;
                                  esac;;
                             "6") read -r -n 1 buf # Page down
                                  case "$buf" in
                                      "~") unset hist_pos
                                           input="$saved_input"
                                           cur_pos="${#input}";;
                                  esac;;
                             "A") if [[ -z "$hist_pos" ]]; then # Up arrow
                                      if [[ "${#history[@]}" -gt 0 ]]; then
                                          saved_input="$input"
                                          hist_pos="$((${#history[@]} - 1))"
                                          input="${history[$hist_pos]}"
                                          cur_pos="${#input}"
                                      fi
                                  elif [[ "$((hist_pos - 1))" -ge 0 ]]; then
                                      hist_pos="$((hist_pos - 1))"
                                      input="${history[$hist_pos]}"
                                      cur_pos="${#input}"
                                  fi;;
                            "B") if [[ -n "$hist_pos" ]]; then # Down arrow
                                     if [[ "$((hist_pos + 1))" -lt "${#history[@]}" ]]; then
                                         hist_pos="$((hist_pos + 1))"
                                         input="${history[$hist_pos]}"
                                         cur_pos="${#input}"
                                     else
                                         input="$saved_input"
                                         cur_pos="${#input}"
                                         unset hist_pos saved_input
                                     fi
                                 fi;;
                            "C") if [[ "$((cur_pos + 1))" -le "${#input}" ]]; then # Right arrow
                                     if [[ "${mod[0]}" == "ctrl" ]]; then
                                         if new_cur_pos="$(word_pos "$input" "${cur_pos:-0}" 1)"; then
                                             cur_pos="$new_cur_pos"
                                         else
                                             cur_pos="${#input}"
                                         fi
                                     else
                                         cur_pos="$((cur_pos + 1))"
                                     fi
                                 fi;;
                            "D") if [[ "$cur_pos" -gt 0 ]]; then # Left arrow
                                     if [[ "${mod[0]}" == "ctrl" ]]; then
                                         if new_cur_pos="$(word_pos "$input" "${cur_pos:-0}" 0)"; then
                                             cur_pos="$new_cur_pos"
                                         else
                                             cur_pos="0"
                                         fi
                                     else
                                         cur_pos="$((cur_pos - 1))"
                                     fi
                                 fi;;
                            "F") cur_pos="${#input}";; # End
                            "H") cur_pos=0;; # Home
                         esac;;
                esac
            else
                input="${input:0:$cur_pos}$buf${input:$cur_pos}"
                cur_pos="$((cur_pos + 1))"
            fi

            stty echo
        done
    done
}

prompt_loop
