open System.IO
open System
open System.Text.RegularExpressions
let vagrantReportRe = new Regex ("(==(\\d+)== +(at|by) )(0x[\\da-fA-F]+)(: \\?\\?\\?)( .+)")
let readSymbols () =
    let lines = File.ReadLines "./bin/syms"
    List.ofSeq <| Seq.map (fun (line : string) ->
        let addr = Convert.ToUInt64 (line.[..15], 16)
        let symb = line.[17..]
        (addr, symb) ) lines

let findSymbol addr symbs =
    let x = List.tryFind (fun (saddr, ssymb) -> saddr <= addr) (List.rev symbs)
    match x with
    | Some (saddr, ssymb) ->
        if saddr = addr
        then sprintf "%s" ssymb
        else sprintf "%s+0x%x" ssymb (addr - saddr)
    | None ->
        sprintf "<unknown> 0x%x" addr

let writeSymbol symbols (matchinf : Match) =
    let grps = matchinf.Groups
    let addr = Convert.ToUInt64 (grps.[4].Value, 16)
    let symbol = findSymbol addr symbols
    sprintf "%s%s: %s%s" grps.[1].Value grps.[4].Value symbol grps.[6].Value


[<EntryPoint>]
let main args =
    let symbols = readSymbols ()
    printf "%s" <| vagrantReportRe.Replace (stdin.ReadToEnd(), writeSymbol symbols)
    0


