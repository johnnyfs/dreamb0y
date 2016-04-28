mapfiles = tup.glob('*_map.png')
utildir = '../util'
uniques = utildir .. '/uniques'
tblcut = utildir .. '/tblcut'
img2chr = utildir .. '/img2chr'
tbl2attr = utildir .. '/tbl2attr'
rowrle = utildir .. '/rowrle'
bin2asm = utildir .. '/bin2asm'
grayscale = 'grayscale.png'

-- Convert every tile of the form *_map.png into uniques, indeces, and palettes, cut to screen-sized units, then covert to NES format.
for k, mapfile in pairs(mapfiles) do 
    stub = string.sub(mapfile, 1, string.len(mapfile) - 8)
    palfile = stub .. '_palettes.png'
    uoutfile = stub .. '_uniques.bmp'
    aoutfile = stub .. '_palettes.tbl'
    toutfile = stub .. '_indeces.tbl'

    tup.definerule {
        inputs = {
            mapfile,
            palfile,
            uniques,
            grayscale
        },
        command = uniques .. ' ' .. mapfile .. ' -p ' .. palfile .. ' -P ' .. grayscale .. ' -o ' .. uoutfile .. ' -a ' .. aoutfile .. ' -t ' .. toutfile,
        outputs = {
            uoutfile,
            aoutfile,
            toutfile
        }
    }
    
    -- Generate rules to cut tile index and palette index files into screen-sized blocks.
    -- NOTE: later we might need to include this info in the fn
    -- (ie, 'realworld_day_map_4x4' => 0..3x0..3.)
    cutfiles = {}
    for y=0,3 do
        for x=0,3 do
            table.insert(cutfiles, '%B_' .. tostring(x) .. '_' .. tostring(y) .. '.tbl')
        end
    end

    cutcmd = tblcut .. ' %f -o %B_%%x_%%y.tbl'
    tup.foreach_rule(
        {
            aoutfile,
            toutfile,
            extra_inputs = tblcut
        },
        cutcmd,
        cutfiles)
end

-- Create rule for converting screen-sized palette index blocks into NES attr format.
tup.foreach_rule(
    {
        '*_palettes_*_*.tbl',
        extra_inputs = tbl2attr
    },
    tbl2attr .. ' %f -o %o',
    '%B.attr')

-- Create rule for converting screen-sized tile index blocks into a RLE-compressed table.
tup.foreach_rule(
    {
        '*_indeces_*_*.tbl',
        extra_inputs = rowrle
    },
    rowrle .. ' %f -o %o',
    '%f.rle')

-- Create rule for converting unique tiles into NES chrs.
tup.foreach_rule(
    {
        '*_uniques.bmp',
        extra_inputs = { img2chr, grayscale }
    },
    img2chr .. ' %f -o %o -p ' .. grayscale,
    '%B.chr')

-- Create rule for converting the attr's, rle's, and chr's into crasm-compatible assembly statements.
tup.foreach_rule(
    {
        '*_palettes_*_*.attr',
        '*_indeces_*_*.tbl.rle',
        '*.chr',
        extra_inputs = bin2asm
    },
    bin2asm .. ' %f -o %o',
    '%f.s')
